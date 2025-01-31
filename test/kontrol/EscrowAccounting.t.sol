pragma solidity 0.8.26;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "contracts/ImmutableDualGovernanceConfigProvider.sol";
import "contracts/DualGovernance.sol";
import "contracts/EmergencyProtectedTimelock.sol";
import {Escrow} from "contracts/Escrow.sol";

import {ISignallingEscrow} from "contracts/interfaces/ISignallingEscrow.sol";
import {DualGovernanceConfig} from "contracts/libraries/DualGovernanceConfig.sol";
import {ETHValue} from "contracts/types/ETHValue.sol";
import {addTo, Duration, Durations} from "contracts/types/Duration.sol";
import {SharesValue} from "contracts/types/SharesValue.sol";
import {Timestamp, Timestamps} from "contracts/types/Timestamp.sol";
import {PercentD16} from "contracts/types/PercentD16.sol";

import "test/kontrol/model/StETHModel.sol";
import "test/kontrol/model/WithdrawalQueueModel.sol";
import "test/kontrol/model/WstETHAdapted.sol";
import "contracts/ResealManager.sol";

import {DualGovernanceSetUp} from "test/kontrol/DualGovernanceSetUp.sol";
import {EscrowInvariants} from "test/kontrol/EscrowInvariants.sol";
import {State as EscrowSt} from "contracts/libraries/EscrowState.sol";
import {UnstETHRecordStatus} from "contracts/libraries/AssetsAccounting.sol";

contract EscrowAccountingTest is EscrowInvariants, DualGovernanceSetUp {
    function testRageQuitSupport() public {
        Escrow escrow = signallingEscrow;

        ISignallingEscrow.SignallingEscrowDetails memory details = escrow.getSignallingEscrowDetails();
        uint256 totalSharesLocked = SharesValue.unwrap(details.totalStETHLockedShares);
        uint256 unfinalizedShares = totalSharesLocked + SharesValue.unwrap(details.totalUnstETHUnfinalizedShares);
        uint256 totalFundsLocked = stEth.getPooledEthByShares(unfinalizedShares);
        uint256 finalizedETH = ETHValue.unwrap(details.totalUnstETHFinalizedETH);
        uint256 expectedRageQuitSupport =
            (totalFundsLocked + finalizedETH) * 1e18 / (stEth.totalSupply() + finalizedETH);

        assert(PercentD16.unwrap(escrow.getRageQuitSupport()) == expectedRageQuitSupport);
    }

    function testEscrowInvariantsHoldInitially(uint32 minAssetsLockDuration) public {
        // Simulate Escrow initialization to get initial state
        Escrow initialEscrow = Escrow(payable(Clones.clone(address(escrowMasterCopy))));
        vm.prank(address(dualGovernance));
        initialEscrow.initialize(Duration.wrap(minAssetsLockDuration));
        this.stEthEscrowSetup(stEth, initialEscrow, withdrawalQueue);

        address sender = _getArbitraryUserAddress();
        this.stEthUserSetup(stEth, sender);

        this.escrowInvariants(Mode.Assert, initialEscrow);
        this.signallingEscrowInvariants(Mode.Assert, initialEscrow);
        this.escrowUserInvariants(Mode.Assert, initialEscrow, sender);
    }

    function testRequestNextWithdrawalsBatch() public {
        Escrow escrow = rageQuitEscrow;
        // For simplicity
        uint256 batchSize = 1;
        assert(batchSize >= escrow.MIN_WITHDRAWALS_BATCH_SIZE());

        vm.assume(!escrow.isWithdrawalsBatchesClosed());
        uint256 batchesLength = _getBatchesLength(escrow);
        _withdrawalsBatchSetup(escrow, batchesLength - 1);

        uint256 lastBatchIndex = batchesLength - 1;
        vm.assume(_getLastUnstEthId(escrow, lastBatchIndex) ==
                  _getLastRequestId(withdrawalQueue));

        // Avoid overflow
        uint64 totalUnstEthIdsCount = _getTotalUnstEthIdsCount(escrow);
        vm.assume(totalUnstEthIdsCount < 2 ** 32);

        this.escrowInvariants(Mode.Assume, escrow);

        escrow.requestNextWithdrawalsBatch(batchSize);

        this.escrowInvariants(Mode.Assert, escrow);
    }

    function testClaimNextWithdrawalsBatch() public {
        Escrow escrow = rageQuitEscrow;

        address sender = _getArbitraryUserAddress();
        this.stEthUserSetup(stEth, sender);

        this.escrowInvariants(Mode.Assume, escrow);
        this.escrowUserInvariants(Mode.Assume, escrow, sender);
        this.claimedBatchesInvariants(Mode.Assume, escrow);

        // Only claim one unstETH for simplicity
        uint256 maxUnstETHIdsCount = 1;

        {
            // Assume the extension period hasn't started
            vm.assume(_getRageQuitExtensionPeriodStartedAt(escrow) == 0);

            // Assume not all batches have been claimed yet
            uint64 unstEthIdsCount = _getTotalUnstEthIdsCount(escrow);
            uint64 unstEthIdsClaimed = _getTotalUnstEthIdsClaimed(escrow);
            vm.assume(unstEthIdsCount != unstEthIdsClaimed);

            // Assume no overflows
            uint256 lastClaimedBatchIndex = _getLastClaimedBatchIndex(escrow);
            uint256 firstUnstEthId = _getFirstUnstEthId(escrow, lastClaimedBatchIndex);
            uint256 lastUnstEthId = _getLastUnstEthId(escrow, lastClaimedBatchIndex);
            uint64 lastClaimedUnstEthIdIndex = _getLastClaimedUnstEthIdIndex(escrow);
            uint256 batchesQueueLength = _getBatchesLength(escrow);
            vm.assume(lastClaimedBatchIndex < type(uint56).max);
            vm.assume(lastUnstEthId - firstUnstEthId < type(uint256).max);
            vm.assume(lastClaimedUnstEthIdIndex < type(uint64).max);
            vm.assume(lastClaimedUnstEthIdIndex + 1 <= type(uint256).max - firstUnstEthId);

            // Set up storage for last and next claimed batch
            _withdrawalsBatchSetup(escrow, lastClaimedBatchIndex);
            _withdrawalsBatchSetup(escrow, lastClaimedBatchIndex + 1);

            // Predict what the next request id will be, to make the proper assumption
            uint256 lastFinalizedRequestId = _getLastFinalizedRequestId(withdrawalQueue);
            uint256 nextRequestId;

            if (lastUnstEthId - firstUnstEthId == lastClaimedUnstEthIdIndex) {
                // If all unstETH in the previous batch have been claimed,
                // start a new batch

                // Assume that there is a next batch
                vm.assume(lastClaimedBatchIndex + 1 < batchesQueueLength);

                uint256 nextBatchIndex = lastClaimedBatchIndex + 1;
                uint256 nextBatchFirstUnstEthId = _getFirstUnstEthId(escrow, nextBatchIndex);
                uint256 nextBatchLastUnstEthId = _getLastUnstEthId(escrow, nextBatchIndex);

                // Assume that unstETH ids are sequential
                vm.assume(nextBatchFirstUnstEthId <= nextBatchLastUnstEthId);
                // Assume no overflows
                vm.assume(nextBatchLastUnstEthId - nextBatchFirstUnstEthId < type(uint256).max);

                nextRequestId = nextBatchFirstUnstEthId;
            } else {
                // Otherwise, continue from the next index in the current batch
                nextRequestId = firstUnstEthId + lastClaimedUnstEthIdIndex + 1;
            }

            // Assume the request to be claimed
            // a) is finalized,
            // b) hasn't been claimed, and
            // c) is owned by the rage quit escrow
            bool nextRequestIsClaimed = _getRequestIsClaimed(withdrawalQueue, nextRequestId);
            address nextRequestOwner = _getRequestOwner(withdrawalQueue, nextRequestId);
            vm.assume(nextRequestId <= lastFinalizedRequestId);
            vm.assume(!nextRequestIsClaimed);
            vm.assume(nextRequestOwner == address(escrow));
        }

        vm.startPrank(sender);
        escrow.claimNextWithdrawalsBatch(maxUnstETHIdsCount);
        vm.stopPrank();

        this.escrowInvariants(Mode.Assert, escrow);
        this.escrowUserInvariants(Mode.Assert, escrow, sender);
        this.claimedBatchesInvariants(Mode.Assert, escrow);
    }
}
