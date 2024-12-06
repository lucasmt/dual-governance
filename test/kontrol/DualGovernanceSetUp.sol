pragma solidity 0.8.26;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import "kontrol-cheatcodes/KontrolCheats.sol";

import "contracts/ImmutableDualGovernanceConfigProvider.sol";
import "contracts/DualGovernance.sol";
import "contracts/EmergencyProtectedTimelock.sol";
import "contracts/Escrow.sol";
import "contracts/model/StETHModel.sol";
import "contracts/model/WstETHAdapted.sol";
import "contracts/model/WithdrawalQueueModel.sol";
import "contracts/ResealManager.sol";

import {DualGovernanceConfig} from "contracts/libraries/DualGovernanceConfig.sol";
import {PercentD16} from "contracts/types/PercentD16.sol";
import {Duration, Durations} from "contracts/types/Duration.sol";
import {Timestamp, Timestamps} from "contracts/types/Timestamp.sol";

import {State} from "contracts/libraries/DualGovernanceStateMachine.sol";

import "test/kontrol/StorageSetup.sol";

contract DualGovernanceSetUp is StorageSetup {
    ImmutableDualGovernanceConfigProvider config;
    DualGovernance dualGovernance;
    EmergencyProtectedTimelock timelock;
    StETHModel stEth;
    WstETHAdapted wstEth;
    WithdrawalQueueModel withdrawalQueue;
    Escrow escrowMasterCopy;
    Escrow signallingEscrow;
    Escrow rageQuitEscrow;
    ResealManager resealManager;

    DualGovernanceConfig.Context governanceConfig;
    EmergencyProtectedTimelock.SanityCheckParams timelockSanityCheckParams;
    DualGovernance.ExternalDependencies dependencies;
    DualGovernance.SanityCheckParams dgSanityCheckParams;

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
        Timestamp rageQuitExtensionPeriodStartedAt
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
                Timestamp.unwrap(config.RAGE_QUIT_EXTENSION_PERIOD_DURATION().addTo(rageQuitExtensionPeriodStartedAt))
            );

            kevm.forgetBranch(
                PercentD16.unwrap(rageQuitSupport),
                KontrolCheatsBase.ComparisonOperator.GreaterThanOrEqual,
                PercentD16.unwrap(config.FIRST_SEAL_RAGE_QUIT_SUPPORT())
            );
        }
    }

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
        timelock = new EmergencyProtectedTimelock(timelockSanityCheckParams, adminExecutor);
        resealManager = new ResealManager(timelock);

        //DualGovernance.ExternalDependencies memory dependencies;
        dependencies.stETH = stEth;
        dependencies.wstETH = wstEth;
        dependencies.withdrawalQueue = withdrawalQueue;
        dependencies.timelock = timelock;
        dependencies.resealManager = resealManager;
        dependencies.configProvider = config;

        dualGovernance = new DualGovernance(dependencies, dgSanityCheckParams);
        escrowMasterCopy = new Escrow(stEth, wstEth, withdrawalQueue, dualGovernance, 1);

        signallingEscrow = Escrow(payable(dualGovernance.getVetoSignallingEscrow()));
        rageQuitEscrow = Escrow(payable(Clones.clone(address(escrowMasterCopy))));

        // ?STORAGE
        // ?WORD: totalPooledEther
        // ?WORD0: totalShares
        // ?WORD1: shares[signallingEscrow]
        // ?WORD2: shares[withdrawalQueue]
        // ?WORD3: allowances[withdrawalQueue]
        this.stEthStorageSetup(stEth, signallingEscrow, withdrawalQueue);

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
        kevm.symbolicStorage(address(timelock));

        // ?STORAGE4
        kevm.symbolicStorage(address(withdrawalQueue));
    }
}
