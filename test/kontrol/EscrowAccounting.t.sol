pragma solidity 0.8.26;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "contracts/ImmutableDualGovernanceConfigProvider.sol";
import "contracts/DualGovernance.sol";
import "contracts/EmergencyProtectedTimelock.sol";
import "contracts/Escrow.sol";

import {DualGovernanceConfig} from "contracts/libraries/DualGovernanceConfig.sol";
import {addTo, Duration, Durations} from "contracts/types/Duration.sol";
import {Timestamp, Timestamps} from "contracts/types/Timestamp.sol";
import {PercentD16} from "contracts/types/PercentD16.sol";

import "contracts/model/StETHModel.sol";
import "contracts/model/WithdrawalQueueModel.sol";
import "contracts/model/WstETHAdapted.sol";
import "contracts/ResealManager.sol";

import {EscrowInvariants} from "test/kontrol/EscrowInvariants.sol";
import {State as EscrowSt} from "contracts/libraries/EscrowState.sol";
import {UnstETHRecordStatus} from "contracts/libraries/AssetsAccounting.sol";

contract EscrowAccountingTest is EscrowInvariants {
    ImmutableDualGovernanceConfigProvider config;
    DualGovernance dualGovernance;
    EmergencyProtectedTimelock timelock;
    StETHModel stEth;
    WstETHAdapted wstEth;
    WithdrawalQueueModel withdrawalQueue;
    IEscrow escrowMasterCopy;
    Escrow escrow;
    Escrow rageQuitEscrow;
    ResealManager resealManager;

    DualGovernanceConfig.Context governanceConfig;
    EmergencyProtectedTimelock.SanityCheckParams timelockSanityCheckParams;
    DualGovernance.ExternalDependencies dependencies;
    DualGovernance.SanityCheckParams dgSanityCheckParams;

    function _setUpInitialState() public {
        vm.chainId(1); // Set block.chainid so it's not symbolic

        stEth = new StETHModel();
        wstEth = new WstETHAdapted(IStETH(stEth));
        withdrawalQueue = new WithdrawalQueueModel(IStETH(stEth));

        // Placeholder addresses
        address adminExecutor = address(uint160(uint256(keccak256("adminExecutor"))));
        address emergencyGovernance = address(uint160(uint256(keccak256("emergencyGovernance"))));

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
        escrowMasterCopy = dualGovernance.ESCROW_MASTER_COPY();
        escrow = Escrow(payable(dualGovernance.getVetoSignallingEscrow()));
        rageQuitEscrow = Escrow(payable(Clones.clone(address(escrowMasterCopy))));

        // ?STORAGE
        // ?WORD: totalPooledEther
        // ?WORD0: totalShares
        // ?WORD1: shares[escrow]
        this.stEthStorageSetup(stEth, escrow, withdrawalQueue);
        this.withdrawalQueueStorageSetup(withdrawalQueue, stEth);
        // Simplifying assumption that there is a rageQuitEscrow
        this.dualGovernanceStorageSetup(dualGovernance, escrow, rageQuitEscrow, config);
        this.escrowStorageSetup(rageQuitEscrow, EscrowSt.RageQuitEscrow);
    }

    function _setUpSignallingEscrow() public {
        _setUpInitialState();

        // ?STORAGE0
        // ?WORD4: lockedShares
        // ?WORD5: claimedETH
        // ?WORD6: unfinalizedShares
        // ?WORD7: finalizedETH
        // ?WORD8: batchesQueue
        // ?WORD9: rageQuitExtensionDelay
        // ?WORD10: rageQuitWithdrawalsTimelock
        // ?WORD11: rageQuitTimelockStartedAt
        this.escrowStorageSetup(escrow, EscrowSt.SignallingEscrow);
    }

    // TODO: Replace this with another setUp function where it's being used
    function _setUpGenericState() public {
        require(false, "Unimplemented");
    }

    function testRageQuitSupport() public {
        _setUpSignallingEscrow();

        uint256 totalSharesLocked = escrow.getLockedAssetsTotals().stETHLockedShares;
        uint256 unfinalizedShares = totalSharesLocked + escrow.getLockedAssetsTotals().unstETHUnfinalizedShares;
        uint256 totalFundsLocked = stEth.getPooledEthByShares(unfinalizedShares);
        uint256 finalizedETH = escrow.getLockedAssetsTotals().unstETHFinalizedETH;
        uint256 expectedRageQuitSupport =
            (totalFundsLocked + finalizedETH) * 1e18 / (stEth.totalSupply() + finalizedETH);

        assert(PercentD16.unwrap(escrow.getRageQuitSupport()) == expectedRageQuitSupport);
    }

    function testEscrowInvariantsHoldInitially() public {
        _setUpInitialState();

        // Placeholder address to avoid complications with keccak of symbolic addresses
        address sender = address(uint160(uint256(keccak256("sender"))));
        this.escrowInvariants(Mode.Assert, escrow);
        this.signallingEscrowInvariants(Mode.Assert, escrow);
        this.escrowUserInvariants(Mode.Assert, escrow, sender);
    }

    function testRequestWithdrawals(uint256 stEthAmount) public {
        _setUpSignallingEscrow();

        // Placeholder address to avoid complications with keccak of symbolic addresses
        address sender = address(uint160(uint256(keccak256("sender"))));
        this.stEthUserSetup(stEth, sender);
        this.escrowUserSetup(escrow, sender);
        this.escrowWithdrawalQueueSetup(escrow, withdrawalQueue);

        AccountingRecord memory pre = this.saveAccountingRecord(sender, escrow);
        uint256 preRageQuitSupport = PercentD16.unwrap(escrow.getRageQuitSupport());

        this.escrowInvariants(Mode.Assume, escrow);
        this.escrowUserInvariants(Mode.Assume, escrow, sender);

        // Only request one withdrawal for simplicity
        vm.assume(stEthAmount >= withdrawalQueue.MIN_STETH_WITHDRAWAL_AMOUNT());
        vm.assume(stEthAmount <= withdrawalQueue.MAX_STETH_WITHDRAWAL_AMOUNT());
        vm.assume(stEthAmount <= stEth.allowance(address(escrow), address(withdrawalQueue)));
        uint256 shares = stEth.getSharesByPooledEth(stEthAmount);
        vm.assume(0 < shares);
        vm.assume(shares <= stEth.sharesOf(address(escrow)));
        vm.assume(shares <= escrow.getVetoerState(sender).stETHLockedShares);
        uint256[] memory stEthAmounts = new uint256[](1);
        stEthAmounts[0] = stEthAmount;

        uint256 lastRequestId = _getLastRequestId(withdrawalQueue);
        UnstETHRecordStatus unstEthRecordStatus =
            UnstETHRecordStatus(_getUnstEthRecordStatus(escrow, lastRequestId + 1));
        vm.assume(unstEthRecordStatus == UnstETHRecordStatus.NotLocked);

        // Ensure SignallingEscrow won't turn into RageQuitEscrow
        vm.assume(
            dualGovernance.getPersistedState() == State.RageQuit || dualGovernance.getEffectiveState() != State.RageQuit
        );

        vm.startPrank(sender);
        escrow.requestWithdrawals(stEthAmounts);
        vm.stopPrank();

        this.escrowInvariants(Mode.Assert, escrow);
        this.escrowUserInvariants(Mode.Assert, escrow, sender);

        AccountingRecord memory post = this.saveAccountingRecord(sender, escrow);
        uint256 postRageQuitSupport = PercentD16.unwrap(escrow.getRageQuitSupport());

        assert(post.userSharesLocked == pre.userSharesLocked - shares);
        assert(post.totalSharesLocked == pre.totalSharesLocked - shares);
        assert(post.userLastLockedTime == Timestamps.now());
        assert(post.userUnstEthLockedShares == pre.userUnstEthLockedShares + shares);
        assert(post.unfinalizedShares == pre.unfinalizedShares + shares);

        // Rage quit support is not affected
        assert(postRageQuitSupport == preRageQuitSupport);
    }

    /*
    function testRequestNextWithdrawalsBatch(uint256 maxBatchSize) public {
        _setUpRageQuitEscrow();

        vm.assume(EscrowSt(_getCurrentState(escrow)) == EscrowSt.RageQuitEscrow);
        vm.assume(maxBatchSize >= escrow.MIN_WITHDRAWALS_BATCH_SIZE());

        this.escrowInvariants(Mode.Assume, escrow);

        escrow.requestNextWithdrawalsBatch(maxBatchSize);

        this.escrowInvariants(Mode.Assert, escrow);
    }

    function testClaimNextWithdrawalsBatch() public {
        _setUpRageQuitEscrow();

        // Placeholder address to avoid complications with keccak of symbolic addresses
        address sender = address(uint160(uint256(keccak256("sender"))));
        vm.assume(stEth.sharesOf(sender) < ethUpperBound);

        vm.assume(EscrowSt(_getCurrentState(escrow)) == EscrowSt.RageQuitEscrow);
        vm.assume(_getRageQuitExtensionPeriodStartedAt(escrow) == 0);

        this.escrowInvariants(Mode.Assume, escrow);
        this.escrowUserInvariants(Mode.Assume, escrow, sender);

        // Only claim one unstETH for simplicity
        uint256 maxUnstETHIdsCount = 1;

        vm.startPrank(sender);
        escrow.claimNextWithdrawalsBatch(maxUnstETHIdsCount);
        vm.stopPrank();

        this.escrowInvariants(Mode.Assert, escrow);
        this.escrowUserInvariants(Mode.Assert, escrow, sender);
    }
    */
}
