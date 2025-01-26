pragma solidity 0.8.26;

import "contracts/DualGovernance.sol";
import "contracts/EmergencyProtectedTimelock.sol";
import {Escrow} from "contracts/Escrow.sol";
import {DualGovernanceConfig} from "contracts/libraries/DualGovernanceConfig.sol";
import {State as EscrowSt} from "contracts/libraries/EscrowState.sol";

import {ISignallingEscrow} from "contracts/interfaces/ISignallingEscrow.sol";
import {addTo, Duration, Durations} from "contracts/types/Duration.sol";
import {SharesValue} from "contracts/types/SharesValue.sol";
import {Timestamp, Timestamps} from "contracts/types/Timestamp.sol";

import "contracts/model/StETHModel.sol";
import "contracts/model/WithdrawalQueueModel.sol";
import "contracts/model/WstETHAdapted.sol";

import {StorageSetup} from "test/kontrol/StorageSetup.sol";

contract EscrowInvariants is StorageSetup {
    function escrowInvariants(Mode mode, Escrow escrow) external view {
        StETHModel stEth = StETHModel(address(escrow.ST_ETH()));
        uint128 totalLockedShares = _getTotalStEthLockedShares(escrow);
        _establish(mode, totalLockedShares + _getUnfinalizedShares(escrow) <= stEth.sharesOf(address(escrow)));
        // TODO: Adapt to updated code
        //_establish(mode, totals.sharesFinalized <= totals.stETHLockedShares);
        uint256 totalLockedEther = stEth.getPooledEthByShares(totalLockedShares);
        _establish(mode, totalLockedEther <= stEth.balanceOf(address(escrow)));
        // TODO: Adapt to updated code
        //_establish(mode, totals.amountFinalized == stEth.getPooledEthByShares(totals.sharesFinalized));
        //_establish(mode, totals.amountFinalized <= totalPooledEther);
        //_establish(mode, totals.amountClaimed <= totals.amountFinalized);
        uint64 unstEthIdsCount = _getTotalUnstEthIdsCount(escrow);
        uint64 unstEthIdsClaimed = _getTotalUnstEthIdsClaimed(escrow);
        _establish(mode, unstEthIdsClaimed <= unstEthIdsCount);
        uint56 lastClaimedBatchIndex = _getLastClaimedBatchIndex(escrow);
        uint256 batchesLength = _getBatchesLength(escrow);
        // <= because they can both be 0 at first
        _establish(mode, lastClaimedBatchIndex <= batchesLength);
        uint256 firstUnstEthId = _getFirstUnstEthId(escrow, lastClaimedBatchIndex);
        uint256 lastUnstEthId = _getLastUnstEthId(escrow, lastClaimedBatchIndex);
        _establish(mode, firstUnstEthId <= lastUnstEthId);

        EscrowSt currentState = EscrowSt(_getCurrentState(escrow));
        _establish(mode, 0 <= uint8(currentState));
        _establish(mode, uint8(currentState) <= 2);
        // WithdrawalQueue has infinite allowance
        address withdrawalQueue = address(escrow.WITHDRAWAL_QUEUE());
        uint256 allowance = stEth.allowance(address(escrow), withdrawalQueue);
        _establish(mode, allowance == type(uint256).max);
    }

    function signallingEscrowInvariants(Mode mode, Escrow escrow) external view {
        // TODO: Adapt to updated code
        /*
        if (_getCurrentState(escrow) == EscrowState.SignallingEscrow) {
            LockedAssetsTotals memory totals = escrow.getLockedAssetsTotals();
            _establish(mode, totals.sharesFinalized == 0);
            _establish(mode, totals.amountFinalized == 0);
            _establish(mode, totals.amountClaimed == 0);
        }
        */
    }

    function escrowUserInvariants(Mode mode, Escrow escrow, address user) external view {
        SharesValue userLockedShares = escrow.getVetoerDetails(user).stETHLockedShares;
        uint128 totalLockedShares = _getTotalStEthLockedShares(escrow);

        _establish(
            mode,
            // Unwrapping because <= is not implemented for SharesValue type
            SharesValue.unwrap(userLockedShares) <= totalLockedShares
        );
    }
}
