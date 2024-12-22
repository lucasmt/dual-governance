pragma solidity 0.8.26;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import "contracts/ImmutableDualGovernanceConfigProvider.sol";
import "contracts/DualGovernance.sol";
import "contracts/EmergencyProtectedTimelock.sol";
import {Escrow} from "contracts/Escrow.sol";
import "contracts/model/StETHModel.sol";
import "contracts/model/WstETHAdapted.sol";
import "contracts/model/WithdrawalQueueModel.sol";
import "contracts/ResealManager.sol";

import {DualGovernanceConfig} from "contracts/libraries/DualGovernanceConfig.sol";
import {PercentD16, PercentsD16} from "contracts/types/PercentD16.sol";
import {Duration, Durations} from "contracts/types/Duration.sol";

import "test/kontrol/ProposalOperationsSetup.sol";
import "test/kontrol/StorageSetup.sol";

contract DualGovernanceSetUp is StorageSetup, ProposalOperationsSetup {
    ImmutableDualGovernanceConfigProvider config;
    DualGovernance dualGovernance;
    EmergencyProtectedTimelock timelock;
    StETHModel stEth;
    WstETHAdapted wstEth;
    WithdrawalQueueModel withdrawalQueue;
    IEscrowBase escrowMasterCopy;
    Escrow signallingEscrow;
    Escrow rageQuitEscrow;
    ResealManager resealManager;

    DualGovernanceConfig.Context governanceConfig;
    EmergencyProtectedTimelock.SanityCheckParams timelockSanityCheckParams;
    DualGovernance.SignallingTokens signallingTokens;
    DualGovernance.DualGovernanceComponents components;
    DualGovernance.SanityCheckParams dgSanityCheckParams;

    function setUp() public {
        vm.chainId(1); // Set block.chainid so it's not symbolic
        vm.assume(block.timestamp < timeUpperBound);

        stEth = new StETHModel();
        wstEth = new WstETHAdapted(IStETH(stEth));
        withdrawalQueue = new WithdrawalQueueModel(IStETH(stEth));

        // Placeholder addresses
        address adminExecutor = address(uint160(uint256(keccak256("adminExecutor"))));
        address emergencyGovernance = address(uint160(uint256(keccak256("emergencyGovernance"))));
        address adminProposer = address(uint160(uint256(keccak256("adminProposer"))));

        governanceConfig = DualGovernanceConfig.Context({
            firstSealRageQuitSupport: PercentsD16.fromBasisPoints(3_00), // 3%
            secondSealRageQuitSupport: PercentsD16.fromBasisPoints(15_00), // 15%
            //
            minAssetsLockDuration: Durations.from(5 hours),
            //
            vetoSignallingMinDuration: Durations.from(3 days),
            vetoSignallingMaxDuration: Durations.from(30 days),
            vetoSignallingMinActiveDuration: Durations.from(5 hours),
            vetoSignallingDeactivationMaxDuration: Durations.from(5 days),
            //
            vetoCooldownDuration: Durations.from(4 days),
            //
            rageQuitExtensionPeriodDuration: Durations.from(7 days),
            rageQuitEthWithdrawalsMinDelay: Durations.from(30 days),
            rageQuitEthWithdrawalsMaxDelay: Durations.from(180 days),
            rageQuitEthWithdrawalsDelayGrowth: Durations.from(15 days)
        });

        config = new ImmutableDualGovernanceConfigProvider(governanceConfig);

        timelockSanityCheckParams = EmergencyProtectedTimelock.SanityCheckParams({
            minExecutionDelay: Durations.from(4 days),
            maxAfterSubmitDelay: Durations.from(14 days),
            maxAfterScheduleDelay: Durations.from(7 days),
            maxEmergencyModeDuration: Durations.from(365 days),
            maxEmergencyProtectionDuration: Durations.from(365 days)
        });
        Duration afterSubmitDelay = Durations.from(3 days);
        Duration afterScheduleDelay = Durations.from(2 days);

        timelock = new EmergencyProtectedTimelock(
            timelockSanityCheckParams, adminExecutor, afterSubmitDelay, afterScheduleDelay
        );
        resealManager = new ResealManager(timelock);

        signallingTokens.stETH = stEth;
        signallingTokens.wstETH = wstEth;
        signallingTokens.withdrawalQueue = withdrawalQueue;
        components.timelock = timelock;
        components.resealManager = resealManager;
        components.configProvider = config;

        dgSanityCheckParams = DualGovernance.SanityCheckParams({
            minWithdrawalsBatchSize: 4,
            minTiebreakerActivationTimeout: Durations.from(30 days),
            maxTiebreakerActivationTimeout: Durations.from(180 days),
            maxSealableWithdrawalBlockersCount: 128,
            maxMinAssetsLockDuration: Durations.from(365 days)
        });

        dualGovernance = new DualGovernance(components, signallingTokens, dgSanityCheckParams);

        signallingEscrow = Escrow(payable(dualGovernance.getVetoSignallingEscrow()));
        escrowMasterCopy = signallingEscrow.ESCROW_MASTER_COPY();
        rageQuitEscrow = Escrow(payable(Clones.clone(address(escrowMasterCopy))));

        // ?STORAGE
        // ?WORD: totalPooledEther
        // ?WORD0: totalShares
        // ?WORD1: shares[signallingEscrow]
        // ?WORD2: shares[withdrawalQueue]
        // ?WORD3: allowances[withdrawalQueue]
        this.stEthInitializeStorage(stEth, signallingEscrow, rageQuitEscrow, withdrawalQueue);

        // ?STORAGE0
        // ?WORD4: currentState
        // ?WORD5: enteredAt
        // ?WORD6: vetoSignallingActivationTime
        // ?WORD7: rageQuitRound
        // ?WORD8: vetoSignallingReactivationTime
        // ?WORD9: normalOrVetoCooldownExitedAt
        this.dualGovernanceInitializeStorage(dualGovernance, signallingEscrow, rageQuitEscrow, config);

        // ?STORAGE1
        this.signallingEscrowInitializeStorage(signallingEscrow);

        // ?STORAGE2
        this.rageQuitEscrowInitializeStorage(rageQuitEscrow);

        // ?STORAGE3
        this.timelockStorageSetup(dualGovernance, timelock);

        // ?STORAGE4
        this.withdrawalQueueStorageSetup(withdrawalQueue, stEth);
    }

    function _calculateDynamicTimelock(PercentD16 rageQuitSupport) public view returns (Duration) {
        if (rageQuitSupport < config.FIRST_SEAL_RAGE_QUIT_SUPPORT()) {
            return Durations.ZERO;
        } else if (rageQuitSupport < config.SECOND_SEAL_RAGE_QUIT_SUPPORT()) {
            return _linearInterpolation(rageQuitSupport);
        } else {
            return config.VETO_SIGNALLING_MAX_DURATION();
        }
    }

    function _linearInterpolation(PercentD16 rageQuitSupport) private view returns (Duration) {
        uint32 L_min = Duration.unwrap(config.VETO_SIGNALLING_MIN_DURATION());
        uint32 L_max = Duration.unwrap(config.VETO_SIGNALLING_MAX_DURATION());
        uint256 interpolation = L_min
            + (
                (PercentD16.unwrap(rageQuitSupport) - PercentD16.unwrap(config.FIRST_SEAL_RAGE_QUIT_SUPPORT()))
                    * (L_max - L_min)
            )
                / (
                    PercentD16.unwrap(config.SECOND_SEAL_RAGE_QUIT_SUPPORT())
                        - PercentD16.unwrap(config.FIRST_SEAL_RAGE_QUIT_SUPPORT())
                );
        assert(interpolation <= type(uint32).max);
        return Duration.wrap(uint32(interpolation));
    }

    function forgetStateTransition(
        State state,
        PercentD16 rageQuitSupport,
        Timestamp vetoSignallingActivatedAt,
        Timestamp vetoSignallingReactivationTime,
        Timestamp enteredAt,
        Timestamp rageQuitExtensionPeriodStartedAt,
        Duration rageQuitExtensionPeriodDuration
    ) public {
        if (state == State.Normal) {
            // Transitions from Normal
            kevm.forgetBranch(
                PercentD16.unwrap(rageQuitSupport),
                KontrolCheatsBase.ComparisonOperator.GreaterThanOrEqual,
                PercentD16.unwrap(config.FIRST_SEAL_RAGE_QUIT_SUPPORT())
            );
        } else if (state == State.VetoSignalling) {
            // Transitions from VetoSignalling
            kevm.forgetBranch(
                Timestamp.unwrap(Timestamps.now()),
                KontrolCheatsBase.ComparisonOperator.GreaterThan,
                Timestamp.unwrap(_calculateDynamicTimelock(rageQuitSupport).addTo(vetoSignallingActivatedAt))
            );

            kevm.forgetBranch(
                PercentD16.unwrap(rageQuitSupport),
                KontrolCheatsBase.ComparisonOperator.GreaterThanOrEqual,
                PercentD16.unwrap(config.SECOND_SEAL_RAGE_QUIT_SUPPORT())
            );

            kevm.forgetBranch(
                Timestamp.unwrap(Timestamps.now()),
                KontrolCheatsBase.ComparisonOperator.GreaterThan,
                Timestamp.unwrap(
                    config.VETO_SIGNALLING_MIN_ACTIVE_DURATION().addTo(
                        Timestamps.max(vetoSignallingReactivationTime, vetoSignallingActivatedAt)
                    )
                )
            );
        } else if (state == State.VetoSignallingDeactivation) {
            // Transitions from VetoSignallingDeactivation
            kevm.forgetBranch(
                Timestamp.unwrap(Timestamps.now()),
                KontrolCheatsBase.ComparisonOperator.GreaterThan,
                Timestamp.unwrap(_calculateDynamicTimelock(rageQuitSupport).addTo(vetoSignallingActivatedAt))
            );

            kevm.forgetBranch(
                PercentD16.unwrap(rageQuitSupport),
                KontrolCheatsBase.ComparisonOperator.GreaterThanOrEqual,
                PercentD16.unwrap(config.SECOND_SEAL_RAGE_QUIT_SUPPORT())
            );

            kevm.forgetBranch(
                Timestamp.unwrap(Timestamps.now()),
                KontrolCheatsBase.ComparisonOperator.GreaterThan,
                Timestamp.unwrap(config.VETO_SIGNALLING_DEACTIVATION_MAX_DURATION().addTo(enteredAt))
            );
        } else if (state == State.VetoCooldown) {
            // Transitions from VetoCooldown
            kevm.forgetBranch(
                Timestamp.unwrap(Timestamps.now()),
                KontrolCheatsBase.ComparisonOperator.GreaterThan,
                Timestamp.unwrap(config.VETO_COOLDOWN_DURATION().addTo(enteredAt))
            );

            kevm.forgetBranch(
                PercentD16.unwrap(rageQuitSupport),
                KontrolCheatsBase.ComparisonOperator.GreaterThanOrEqual,
                PercentD16.unwrap(config.FIRST_SEAL_RAGE_QUIT_SUPPORT())
            );
        } else if (state == State.RageQuit) {
            // Transitions from RageQuit
            kevm.forgetBranch(
                Timestamp.unwrap(Timestamps.now()),
                KontrolCheatsBase.ComparisonOperator.GreaterThan,
                Timestamp.unwrap(rageQuitExtensionPeriodDuration.addTo(rageQuitExtensionPeriodStartedAt))
            );

            kevm.forgetBranch(
                PercentD16.unwrap(rageQuitSupport),
                KontrolCheatsBase.ComparisonOperator.GreaterThanOrEqual,
                PercentD16.unwrap(config.FIRST_SEAL_RAGE_QUIT_SUPPORT())
            );
        }
    }
}
