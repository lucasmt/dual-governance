pragma solidity 0.8.26;

import "contracts/DualGovernance.sol";
//import {State as DualGovernanceState} from "contracts/libraries/DualGovernanceStateMachine.sol";
import "contracts/EmergencyProtectedTimelock.sol";
import "contracts/Escrow.sol";

import {Timestamp} from "contracts/types/Timestamp.sol";
import {State as WithdrawalBatchesQueueState} from "contracts/libraries/WithdrawalBatchesQueue.sol";
import {State as EscrowSt} from "contracts/libraries/EscrowState.sol";

import "contracts/model/StETHModel.sol";
import "contracts/model/WithdrawalQueueModel.sol";
import "contracts/model/WstETHAdapted.sol";

import "test/kontrol/KontrolTest.sol";

contract StorageSetup is KontrolTest {
    //
    //  STETH
    //
    function stEthStorageSetup(StETHModel _stEth, IEscrow _escrow, IWithdrawalQueue _withdrawalQueue) external {
        kevm.symbolicStorage(address(_stEth));
        // Slot 0
        uint256 totalPooledEther = kevm.freshUInt(32);
        vm.assume(0 < totalPooledEther);
        vm.assume(totalPooledEther < ethUpperBound);
        _stEth.setTotalPooledEther(totalPooledEther);
        // Slot 1
        uint256 totalShares = kevm.freshUInt(32);
        vm.assume(0 < totalShares);
        vm.assume(totalShares < ethUpperBound);
        _stEth.setTotalShares(totalShares);
        // Slot 2
        uint256 escrowShares = kevm.freshUInt(32);
        vm.assume(escrowShares < totalShares);
        vm.assume(escrowShares < ethUpperBound);
        _stEth.setShares(address(_escrow), escrowShares);
        //
        uint256 queueShares = kevm.freshUInt(32);
        vm.assume(queueShares < totalShares);
        vm.assume(queueShares < ethUpperBound);
        _stEth.setShares(address(_withdrawalQueue), queueShares);
        //
        uint256 queueAllowance = type(uint256).max;
        _stEth.setAllowances(address(_escrow), address(_withdrawalQueue), queueAllowance);
    }

    function stEthUserSetup(StETHModel _stEth, address _user) external {
        uint256 userShares = kevm.freshUInt(32);
        vm.assume(userShares < _stEth.getTotalShares());
        vm.assume(userShares < ethUpperBound);
        _stEth.setShares(_user, userShares);
    }

    function stEthStorageInvariants(Mode mode, StETHModel _stEth, IEscrow _escrow) external {
        uint256 totalPooledEther = _stEth.getTotalPooledEther();
        uint256 totalShares = _stEth.getTotalShares();
        uint256 escrowShares = _stEth.sharesOf(address(_escrow));

        _establish(mode, 0 < _stEth.getTotalPooledEther());
        _establish(mode, 0 < _stEth.getTotalShares());
        _establish(mode, escrowShares < totalShares);
    }

    function stEthAssumeBounds(StETHModel _stEth, IEscrow _escrow) external {
        uint256 totalPooledEther = _stEth.getTotalPooledEther();
        uint256 totalShares = _stEth.getTotalShares();
        uint256 escrowShares = _stEth.sharesOf(address(_escrow));

        vm.assume(totalPooledEther < ethUpperBound);
        vm.assume(totalShares < ethUpperBound);
        vm.assume(escrowShares < ethUpperBound);
    }

    //
    //  WSTETH
    //
    function _wstEthStorageSetup(WstETHAdapted _wstEth, IStETH _stEth) internal {
        kevm.symbolicStorage(address(_wstEth));
    }

    //
    // WithdrawalQueue
    //
    function _getLastRequestId(WithdrawalQueueModel _withdrawalQueue) internal view returns (uint256) {
        return _loadData(address(_withdrawalQueue), 7, 0, 32);
    }

    function withdrawalQueueStorageSetup(WithdrawalQueueModel _withdrawalQueue, IStETH _stEth) external {
        kevm.symbolicStorage(address(_withdrawalQueue));
        _storeUInt256(address(_withdrawalQueue), 6, uint256(uint160(address(_stEth))));
        // Assuming 0 for simplicity
        uint256 lastRequestId = 0;
        //vm.assume(lastRequestId < type(uint256).max);
        _storeUInt256(address(_withdrawalQueue), 7, lastRequestId);
        uint256 owner = 0;
        _storeMappingUInt256(address(_withdrawalQueue), 2, lastRequestId + 1, 0, owner);
    }

    //
    //  DUAL GOVERNANCE
    //
    function _getCurrentState(DualGovernance _dualGovernance) internal view returns (uint8) {
        return uint8(_loadData(address(_dualGovernance), 6, 0, 1));
    }

    function _getEnteredAt(DualGovernance _dualGovernance) internal view returns (uint40) {
        return uint40(_loadData(address(_dualGovernance), 6, 1, 5));
    }

    function _getVetoSignallingActivationTime(DualGovernance _dualGovernance) internal view returns (uint40) {
        return uint40(_loadData(address(_dualGovernance), 6, 6, 5));
    }

    function _getRageQuitRound(DualGovernance _dualGovernance) internal view returns (uint8) {
        return uint8(_loadData(address(_dualGovernance), 6, 31, 1));
    }

    function _getVetoSignallingReactivationTime(DualGovernance _dualGovernance) internal view returns (uint40) {
        return uint40(_loadData(address(_dualGovernance), 7, 0, 5));
    }

    function _getNormalOrVetoCooldownExitedAt(DualGovernance _dualGovernance) internal view returns (uint40) {
        return uint40(_loadData(address(_dualGovernance), 7, 5, 5));
    }

    function dualGovernanceStorageSetup(
        DualGovernance _dualGovernance,
        IEscrow _signallingEscrow,
        IEscrow _rageQuitEscrow,
        IDualGovernanceConfigProvider _config
    ) external {
        kevm.symbolicStorage(address(_dualGovernance));

        // Slot 6:
        uint256 currentState = kevm.freshUInt(1);
        vm.assume(currentState != 0); // Cannot be Unset as dual governance was initialised
        vm.assume(currentState <= 5);
        uint256 enteredAt = kevm.freshUInt(5);
        vm.assume(enteredAt <= block.timestamp);
        vm.assume(enteredAt < timeUpperBound);
        uint256 vetoSignallingActivationTime = kevm.freshUInt(5);
        vm.assume(vetoSignallingActivationTime <= block.timestamp);
        vm.assume(vetoSignallingActivationTime < timeUpperBound);
        uint256 rageQuitRound = kevm.freshUInt(1);
        vm.assume(rageQuitRound < type(uint8).max);

        _storeData(address(_dualGovernance), 6, 0, 1, currentState);
        _storeData(address(_dualGovernance), 6, 1, 5, enteredAt);
        _storeData(address(_dualGovernance), 6, 6, 5, vetoSignallingActivationTime);
        _storeData(address(_dualGovernance), 6, 11, 20, uint256(uint160(address(_signallingEscrow))));
        _storeData(address(_dualGovernance), 6, 31, 1, rageQuitRound);

        // Slot 7
        uint256 vetoSignallingReactivationTime = kevm.freshUInt(5);
        vm.assume(vetoSignallingReactivationTime <= block.timestamp);
        vm.assume(vetoSignallingReactivationTime < timeUpperBound);
        uint256 normalOrVetoCooldownExitedAt = kevm.freshUInt(5);
        vm.assume(normalOrVetoCooldownExitedAt <= block.timestamp);
        vm.assume(normalOrVetoCooldownExitedAt < timeUpperBound);

        _storeData(address(_dualGovernance), 7, 0, 5, vetoSignallingReactivationTime);
        _storeData(address(_dualGovernance), 7, 5, 5, normalOrVetoCooldownExitedAt);
        _storeData(address(_dualGovernance), 7, 10, 22, uint256(uint160(address(_rageQuitEscrow))));

        // Slot 8
        _storeUInt256(address(_dualGovernance), 8, uint256(uint160(address(_config))));
    }

    function dualGovernanceStorageInvariants(Mode mode, DualGovernance _dualGovernance) external {
        uint8 currentState = _getCurrentState(_dualGovernance);
        uint40 enteredAt = _getEnteredAt(_dualGovernance);
        uint40 vetoSignallingActivationTime = _getVetoSignallingActivationTime(_dualGovernance);
        uint40 vetoSignallingReactivationTime = _getVetoSignallingReactivationTime(_dualGovernance);
        uint40 normalOrVetoCooldownExitedAt = _getNormalOrVetoCooldownExitedAt(_dualGovernance);
        uint8 rageQuitRound = _getRageQuitRound(_dualGovernance);

        _establish(mode, currentState <= 5);
        _establish(mode, enteredAt <= block.timestamp);
        _establish(mode, vetoSignallingActivationTime <= block.timestamp);
        _establish(mode, vetoSignallingReactivationTime <= block.timestamp);
        _establish(mode, normalOrVetoCooldownExitedAt <= block.timestamp);
    }

    function dualGovernanceAssumeBounds(DualGovernance _dualGovernance) external {
        uint40 enteredAt = _getEnteredAt(_dualGovernance);
        uint40 vetoSignallingActivationTime = _getVetoSignallingActivationTime(_dualGovernance);
        uint40 vetoSignallingReactivationTime = _getVetoSignallingReactivationTime(_dualGovernance);
        uint40 normalOrVetoCooldownExitedAt = _getNormalOrVetoCooldownExitedAt(_dualGovernance);
        uint8 rageQuitRound = _getRageQuitRound(_dualGovernance);

        vm.assume(enteredAt < timeUpperBound);
        vm.assume(vetoSignallingActivationTime < timeUpperBound);
        vm.assume(vetoSignallingReactivationTime < timeUpperBound);
        vm.assume(normalOrVetoCooldownExitedAt < timeUpperBound);
        vm.assume(rageQuitRound < type(uint8).max);
    }

    function dualGovernanceInitializeStorage(
        DualGovernance _dualGovernance,
        IEscrow _signallingEscrow,
        IEscrow _rageQuitEscrow,
        IDualGovernanceConfigProvider _config
    ) external {
        this.dualGovernanceStorageSetup(_dualGovernance, _signallingEscrow, _rageQuitEscrow, _config);
        this.dualGovernanceStorageInvariants(Mode.Assume, _dualGovernance);
        this.dualGovernanceAssumeBounds(_dualGovernance);
    }

    //
    //  ESCROW
    //
    function _getCurrentState(IEscrow _escrow) internal view returns (uint8) {
        return uint8(_loadData(address(_escrow), 0, 0, 1));
    }

    function _getMinAssetsLockDuration(IEscrow _escrow) internal view returns (uint32) {
        return uint32(_loadData(address(_escrow), 0, 1, 4));
    }

    function _getRageQuitExtensionPeriodDuration(IEscrow _escrow) internal view returns (uint32) {
        return uint32(_loadData(address(_escrow), 0, 5, 4));
    }

    function _getRageQuitExtensionPeriodStartedAt(IEscrow _escrow) internal view returns (uint40) {
        return uint40(_loadData(address(_escrow), 0, 9, 5));
    }

    function _getRageQuitEthWithdrawalsDelay(IEscrow _escrow) internal view returns (uint32) {
        return uint32(_loadData(address(_escrow), 0, 14, 4));
    }

    function _getStEthLockedShares(IEscrow _escrow) internal view returns (uint128) {
        return uint128(_loadData(address(_escrow), 1, 0, 16));
    }

    function _getClaimedEth(IEscrow _escrow) internal view returns (uint128) {
        return uint128(_loadData(address(_escrow), 1, 16, 16));
    }

    function _getUnfinalizedShares(IEscrow _escrow) internal view returns (uint128) {
        return uint128(_loadData(address(_escrow), 2, 0, 16));
    }

    function _getFinalizedEth(IEscrow _escrow) internal view returns (uint128) {
        return uint128(_loadData(address(_escrow), 2, 16, 16));
    }

    function _getLastAssetsLockTimestamp(IEscrow _escrow, address _vetoer) internal view returns (uint40) {
        uint256 key = uint256(uint160(_vetoer));
        return uint40(_loadMappingData(address(_escrow), 3, key, 0, 0, 5));
    }

    function _getBatchesQueueStatus(IEscrow _escrow) internal view returns (uint8) {
        return uint8(_loadData(address(_escrow), 5, 0, 1));
    }

    function _getUnstEthRecordStatus(IEscrow _escrow, uint256 _requestId) internal view returns (uint8) {
        return uint8(_loadMappingData(address(_escrow), 4, _requestId, 0, 0, 1));
    }

    struct AccountingRecord {
        uint256 allowance;
        uint256 userBalance;
        uint256 escrowBalance;
        uint256 userShares;
        uint256 escrowShares;
        uint256 userSharesLocked;
        uint256 totalSharesLocked;
        uint256 totalEth;
        uint256 userUnstEthLockedShares;
        uint256 unfinalizedShares;
        Timestamp userLastLockedTime;
    }

    struct EscrowRecord {
        EscrowSt escrowState;
        AccountingRecord accounting;
    }

    function saveEscrowRecord(address user, Escrow escrow) external view returns (EscrowRecord memory er) {
        AccountingRecord memory accountingRecord = this.saveAccountingRecord(user, escrow);
        er.escrowState = EscrowSt(_getCurrentState(escrow));
        er.accounting = accountingRecord;
    }

    function saveAccountingRecord(address user, Escrow escrow) external view returns (AccountingRecord memory ar) {
        IStETH stEth = escrow.ST_ETH();
        ar.allowance = stEth.allowance(user, address(escrow));
        ar.userBalance = stEth.balanceOf(user);
        ar.escrowBalance = stEth.balanceOf(address(escrow));
        //ar.userShares = stEth.sharesOf(user);
        //ar.escrowShares = stEth.sharesOf(address(escrow));
        ar.userSharesLocked = escrow.getVetoerState(user).stETHLockedShares;
        ar.totalSharesLocked = escrow.getLockedAssetsTotals().stETHLockedShares;
        ar.totalEth = stEth.getPooledEthByShares(ar.totalSharesLocked);
        ar.userUnstEthLockedShares = escrow.getVetoerState(user).unstETHLockedShares;
        ar.unfinalizedShares = escrow.getLockedAssetsTotals().unstETHUnfinalizedShares;
        uint256 lastAssetsLockTimestamp = _getLastAssetsLockTimestamp(escrow, user);
        require(lastAssetsLockTimestamp < timeUpperBound, "lastAssetsLockTimestamp >= timeUpperBound");
        ar.userLastLockedTime = Timestamp.wrap(uint40(lastAssetsLockTimestamp));
    }

    function establishEqualAccountingRecords(
        Mode mode,
        AccountingRecord memory ar1,
        AccountingRecord memory ar2
    ) external view {
        _establish(mode, ar1.allowance == ar2.allowance);
        _establish(mode, ar1.userBalance == ar2.userBalance);
        _establish(mode, ar1.escrowBalance == ar2.escrowBalance);
        _establish(mode, ar1.userShares == ar2.userShares);
        _establish(mode, ar1.escrowShares == ar2.escrowShares);
        _establish(mode, ar1.userSharesLocked == ar2.userSharesLocked);
        _establish(mode, ar1.totalSharesLocked == ar2.totalSharesLocked);
        _establish(mode, ar1.totalEth == ar2.totalEth);
        _establish(mode, ar1.userUnstEthLockedShares == ar2.userUnstEthLockedShares);
        _establish(mode, ar1.unfinalizedShares == ar2.unfinalizedShares);
        _establish(mode, ar1.userLastLockedTime == ar2.userLastLockedTime);
    }

    //
    //  STUCK HERE
    //
    function escrowStorageSetup(IEscrow _escrow, EscrowSt _currentState) external {
        kevm.symbolicStorage(address(_escrow));

        // Slot 0
        {
            _storeData(address(_escrow), 0, 0, 1, uint256(_currentState));

            uint256 minAssetsLockDuration = kevm.freshUInt(4);
            vm.assume(minAssetsLockDuration <= block.timestamp);
            vm.assume(minAssetsLockDuration < timeUpperBound);
            _storeData(address(_escrow), 0, 1, 4, minAssetsLockDuration);

            if (_currentState == EscrowSt.RageQuitEscrow) {
                uint256 rageQuitExtensionPeriodDuration = kevm.freshUInt(4);
                vm.assume(rageQuitExtensionPeriodDuration <= block.timestamp);
                vm.assume(rageQuitExtensionPeriodDuration < timeUpperBound);
                uint256 rageQuitExtensionPeriodStartedAt = kevm.freshUInt(5);
                vm.assume(rageQuitExtensionPeriodStartedAt <= block.timestamp);
                vm.assume(rageQuitExtensionPeriodStartedAt < timeUpperBound);
                uint256 rageQuitEthWithdrawalsDelay = kevm.freshUInt(4);
                vm.assume(rageQuitEthWithdrawalsDelay <= block.timestamp);
                vm.assume(rageQuitEthWithdrawalsDelay < timeUpperBound);

                _storeData(address(_escrow), 0, 5, 4, rageQuitExtensionPeriodDuration);
                _storeData(address(_escrow), 0, 9, 5, rageQuitExtensionPeriodStartedAt);
                _storeData(address(_escrow), 0, 14, 18, rageQuitEthWithdrawalsDelay);
            } else {
                _storeData(address(_escrow), 0, 5, 27, uint256(0));
            }
        }
        // Slot 1
        {
            uint256 lockedShares = kevm.freshUInt(16);
            vm.assume(lockedShares < ethUpperBound);
            uint256 claimedEth = kevm.freshUInt(16);
            vm.assume(claimedEth < ethUpperBound);

            _storeData(address(_escrow), 1, 0, 16, lockedShares);
            _storeData(address(_escrow), 1, 16, 16, claimedEth);
        }
        // Slot 2
        {
            uint256 unfinalizedShares = kevm.freshUInt(16);
            vm.assume(unfinalizedShares < ethUpperBound);
            uint256 finalizedEth = kevm.freshUInt(16);
            vm.assume(finalizedEth < ethUpperBound);

            _storeData(address(_escrow), 2, 0, 16, unfinalizedShares);
            _storeData(address(_escrow), 2, 16, 16, finalizedEth);
        }
        // Slot 5
        if (_currentState == EscrowSt.RageQuitEscrow) {
            uint256 batchesQueueStatus = kevm.freshUInt(1);
            vm.assume(batchesQueueStatus <= 2);
            _storeData(address(_escrow), 5, 0, 1, batchesQueueStatus);
        } else {
            _storeData(address(_escrow), 5, 0, 1, 0);
        }
        // Slot 6
        if (_currentState == EscrowSt.RageQuitEscrow) {
            uint256 batchesQueueLength = uint256(kevm.freshUInt(32));
            vm.assume(batchesQueueLength < 2 ** 64);
            _storeUInt256(address(_escrow), 6, batchesQueueLength);
        } else {
            _storeUInt256(address(_escrow), 6, 0);
        }
    }

    function escrowUserSetup(IEscrow _escrow, address _user) external {
        uint256 key = uint256(uint160(_user));
        uint256 lastAssetsLockTimestamp = kevm.freshUInt(5);
        vm.assume(lastAssetsLockTimestamp <= block.timestamp);
        vm.assume(lastAssetsLockTimestamp < timeUpperBound);
        _storeMappingData(address(_escrow), 3, key, 0, 0, 5, lastAssetsLockTimestamp);
        uint256 stETHLockedShares = kevm.freshUInt(16);
        vm.assume(stETHLockedShares < ethUpperBound);
        _storeMappingData(address(_escrow), 3, key, 0, 5, 27, stETHLockedShares);
        uint256 unstEthLockedShares = kevm.freshUInt(16);
        vm.assume(unstEthLockedShares < ethUpperBound);
        _storeMappingUInt256(address(_escrow), 3, key, 1, unstEthLockedShares);
        uint256 unstEthIdsLength = kevm.freshUInt(32);
        vm.assume(unstEthIdsLength < type(uint32).max);
        _storeMappingUInt256(address(_escrow), 3, key, 2, unstEthIdsLength);
    }

    function escrowWithdrawalQueueSetup(IEscrow _escrow, WithdrawalQueueModel _withdrawalQueue) external {
        uint256 lastRequestId = _getLastRequestId(_withdrawalQueue);
        uint256 unstEthRecordStatus = kevm.freshUInt(1);
        vm.assume(unstEthRecordStatus < 5);
        _storeMappingData(address(_escrow), 4, lastRequestId + 1, 0, 0, 1, unstEthRecordStatus);
    }

    function escrowStorageInvariants(Mode mode, IEscrow _escrow) external {
        uint8 batchesQueueStatus = _getBatchesQueueStatus(_escrow);
        uint32 rageQuitEthWithdrawalsDelay = _getRageQuitEthWithdrawalsDelay(_escrow);
        uint32 rageQuitExtensionPeriodDuration = _getRageQuitExtensionPeriodDuration(_escrow);
        uint40 rageQuitExtensionPeriodStartedAt = _getRageQuitExtensionPeriodStartedAt(_escrow);

        _establish(mode, batchesQueueStatus <= 2);
        _establish(mode, rageQuitEthWithdrawalsDelay <= block.timestamp);
        _establish(mode, rageQuitExtensionPeriodDuration <= block.timestamp);
        _establish(mode, rageQuitExtensionPeriodStartedAt <= block.timestamp);
    }

    function escrowAssumeBounds(IEscrow _escrow) external {
        uint128 lockedShares = _getStEthLockedShares(_escrow);
        uint128 claimedEth = _getClaimedEth(_escrow);
        uint128 unfinalizedShares = _getUnfinalizedShares(_escrow);
        uint128 finalizedEth = _getFinalizedEth(_escrow);
        uint32 rageQuitEthWithdrawalsDelay = _getRageQuitEthWithdrawalsDelay(_escrow);
        uint32 rageQuitExtensionPeriodDuration = _getRageQuitExtensionPeriodDuration(_escrow);
        uint40 rageQuitExtensionPeriodStartedAt = _getRageQuitExtensionPeriodStartedAt(_escrow);

        vm.assume(lockedShares < ethUpperBound);
        vm.assume(claimedEth < ethUpperBound);
        vm.assume(unfinalizedShares < ethUpperBound);
        vm.assume(finalizedEth < ethUpperBound);
        vm.assume(rageQuitEthWithdrawalsDelay < timeUpperBound);
        vm.assume(rageQuitExtensionPeriodDuration < timeUpperBound);
        vm.assume(rageQuitExtensionPeriodStartedAt < timeUpperBound);
    }

    function escrowInitializeStorage(IEscrow _escrow, EscrowSt _currentState) external {
        this.escrowStorageSetup(_escrow, _currentState);
        this.escrowStorageInvariants(Mode.Assume, _escrow);
        this.escrowAssumeBounds(_escrow);
    }

    function signallingEscrowStorageInvariants(Mode mode, IEscrow _signallingEscrow) external {
        uint32 rageQuitEthWithdrawalsDelay = _getRageQuitEthWithdrawalsDelay(_signallingEscrow);
        uint32 rageQuitExtensionPeriodDuration = _getRageQuitExtensionPeriodDuration(_signallingEscrow);
        uint40 rageQuitExtensionPeriodStartedAt = _getRageQuitExtensionPeriodStartedAt(_signallingEscrow);
        uint8 batchesQueueStatus = _getBatchesQueueStatus(_signallingEscrow);

        _establish(mode, rageQuitEthWithdrawalsDelay == 0);
        _establish(mode, rageQuitExtensionPeriodDuration == 0);
        _establish(mode, rageQuitExtensionPeriodStartedAt == 0);
        _establish(mode, batchesQueueStatus == uint8(WithdrawalBatchesQueueState.Absent));
    }

    function signallingEscrowInitializeStorage(IEscrow _signallingEscrow) external {
        this.escrowInitializeStorage(_signallingEscrow, EscrowSt.SignallingEscrow);
        this.signallingEscrowStorageInvariants(Mode.Assume, _signallingEscrow);
    }

    function rageQuitEscrowStorageInvariants(Mode mode, IEscrow _rageQuitEscrow) external {
        uint8 batchesQueueStatus = _getBatchesQueueStatus(_rageQuitEscrow);

        _establish(mode, batchesQueueStatus != uint8(WithdrawalBatchesQueueState.Absent));
    }

    function rageQuitEscrowInitializeStorage(IEscrow _rageQuitEscrow) external {
        this.escrowInitializeStorage(_rageQuitEscrow, EscrowSt.RageQuitEscrow);
        this.rageQuitEscrowStorageInvariants(Mode.Assume, _rageQuitEscrow);
    }
}
