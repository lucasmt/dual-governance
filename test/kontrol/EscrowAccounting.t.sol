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

import {DualGovernanceSetUp} from "test/kontrol/DualGovernanceSetUp.sol";
import {EscrowInvariants} from "test/kontrol/EscrowInvariants.sol";
import {State as EscrowSt} from "contracts/libraries/EscrowState.sol";
import {UnstETHRecordStatus} from "contracts/libraries/AssetsAccounting.sol";

contract EscrowAccountingTest is EscrowInvariants, DualGovernanceSetUp {
    function testRageQuitSupport(bool isRageQuitEscrow) public {
        Escrow escrow = isRageQuitEscrow ? rageQuitEscrow : signallingEscrow;

        uint256 totalSharesLocked = escrow.getLockedAssetsTotals().stETHLockedShares;
        uint256 unfinalizedShares = totalSharesLocked + escrow.getLockedAssetsTotals().unstETHUnfinalizedShares;
        uint256 totalFundsLocked = stEth.getPooledEthByShares(unfinalizedShares);
        uint256 finalizedETH = escrow.getLockedAssetsTotals().unstETHFinalizedETH;
        uint256 expectedRageQuitSupport =
            (totalFundsLocked + finalizedETH) * 1e18 / (stEth.totalSupply() + finalizedETH);

        assert(PercentD16.unwrap(escrow.getRageQuitSupport()) == expectedRageQuitSupport);
    }

    function testEscrowInvariantsHoldInitially(uint32 minAssetsLockDuration) public {
        // Simulate Escrow initialization to get initial state
        Escrow initialEscrow = Escrow(payable(Clones.clone(address(escrowMasterCopy))));
        vm.prank(address(dualGovernance));
        initialEscrow.initialize(Duration.wrap(minAssetsLockDuration));

        // Placeholder address to avoid complications with keccak of symbolic addresses
        address sender = address(uint160(uint256(keccak256("sender"))));
        this.escrowInvariants(Mode.Assert, initialEscrow);
        this.signallingEscrowInvariants(Mode.Assert, initialEscrow);
        this.escrowUserInvariants(Mode.Assert, initialEscrow, sender);
    }

    function testRequestWithdrawals(uint256 stEthAmount) public {
        Escrow escrow = signallingEscrow;

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

    function testRequestNextWithdrawalsBatch(uint256 maxBatchSize) public {
        Escrow escrow = rageQuitEscrow;

        vm.assume(maxBatchSize >= escrow.MIN_WITHDRAWALS_BATCH_SIZE());

        this.escrowInvariants(Mode.Assume, escrow);

        escrow.requestNextWithdrawalsBatch(maxBatchSize);

        this.escrowInvariants(Mode.Assert, escrow);
    }

    function testClaimNextWithdrawalsBatch() public {
        Escrow escrow = rageQuitEscrow;

        // Placeholder address to avoid complications with keccak of symbolic addresses
        address sender = address(uint160(uint256(keccak256("sender"))));
        vm.assume(stEth.sharesOf(sender) < ethUpperBound);

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
}
