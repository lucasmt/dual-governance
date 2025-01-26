pragma solidity 0.8.26;

import "contracts/DualGovernance.sol";
//import {State as DualGovernanceState} from "contracts/libraries/DualGovernanceStateMachine.sol";
import "contracts/EmergencyProtectedTimelock.sol";
import {Escrow} from "contracts/Escrow.sol";

import {SharesValue} from "contracts/types/SharesValue.sol";
import {Timestamp} from "contracts/types/Timestamp.sol";
import {State as WithdrawalsBatchesQueueState} from "contracts/libraries/WithdrawalsBatchesQueue.sol";
import {State as EscrowSt} from "contracts/libraries/EscrowState.sol";

import "contracts/model/StETHModel.sol";
import "contracts/model/WithdrawalQueueModel.sol";
import "contracts/model/WstETHAdapted.sol";

import "test/kontrol/KontrolTest.sol";
import "test/kontrol/storage/DualGovernanceStorageConstants.sol";
import "test/kontrol/storage/EscrowStorageConstants.sol";
import "test/kontrol/storage/WithdrawalQueueStorageConstants.sol";

contract StorageSetup is KontrolTest {
    //
    //  STETH
    //
    function stEthStorageSetup(StETHModel _stEth, IWithdrawalQueue _withdrawalQueue) external {
        kevm.symbolicStorage(address(_stEth));
        // Slot 0
        uint256 totalPooledEther = freshUInt256("ST_TPE");
        vm.assume(0 < totalPooledEther);
        vm.assume(totalPooledEther < ethUpperBound);
        _stEth.setTotalPooledEther(totalPooledEther);
        // Slot 1
        uint256 totalShares = freshUInt256("ST_TSH");
        vm.assume(0 < totalShares);
        vm.assume(totalShares < ethUpperBound);
        _stEth.setTotalShares(totalShares);
        //
        uint256 queueShares = freshUInt256("ST_QSH");
        vm.assume(queueShares < totalShares);
        vm.assume(queueShares < ethUpperBound);
        _stEth.setShares(address(_withdrawalQueue), queueShares);
    }

    function stEthEscrowSetup(StETHModel _stEth, IEscrowBase _escrow, IWithdrawalQueue _withdrawalQueue) external {
        //
        uint256 escrowShares = freshUInt256("ST_ESH");
        vm.assume(escrowShares < _stEth.getTotalShares());
        vm.assume(escrowShares < ethUpperBound);
        _stEth.setShares(address(_escrow), escrowShares);
        //
        uint256 queueAllowance = type(uint256).max;
        _stEth.setAllowances(address(_escrow), address(_withdrawalQueue), queueAllowance);
    }

    function stEthUserSetup(StETHModel _stEth, address _user) external {
        uint256 userShares = freshUInt256("ST_USH");
        vm.assume(userShares < _stEth.getTotalShares());
        vm.assume(userShares < ethUpperBound);
        _stEth.setShares(_user, userShares);
    }

    function stEthStorageInvariants(Mode mode, StETHModel _stEth, IEscrowBase _escrow) external {
        uint256 totalPooledEther = _stEth.getTotalPooledEther();
        uint256 totalShares = _stEth.getTotalShares();
        uint256 escrowShares = _stEth.sharesOf(address(_escrow));

        _establish(mode, 0 < _stEth.getTotalPooledEther());
        _establish(mode, 0 < _stEth.getTotalShares());
        _establish(mode, escrowShares < totalShares);
    }

    function stEthAssumeBounds(StETHModel _stEth, IEscrowBase _escrow) external {
        uint256 totalPooledEther = _stEth.getTotalPooledEther();
        uint256 totalShares = _stEth.getTotalShares();
        uint256 escrowShares = _stEth.sharesOf(address(_escrow));

        vm.assume(totalPooledEther < ethUpperBound);
        vm.assume(totalShares < ethUpperBound);
        vm.assume(escrowShares < ethUpperBound);
    }

    function stEthInitializeStorage(
        StETHModel _stEth,
        IEscrowBase _signallingEscrow,
        IEscrowBase _rageQuitEscrow,
        IWithdrawalQueue _withdrawalQueue
    ) external {
        this.stEthStorageSetup(_stEth, _withdrawalQueue);
        this.stEthEscrowSetup(_stEth, _signallingEscrow, _withdrawalQueue);
        this.stEthEscrowSetup(_stEth, _rageQuitEscrow, _withdrawalQueue);
        this.stEthStorageInvariants(Mode.Assume, _stEth, _signallingEscrow);
        this.stEthStorageInvariants(Mode.Assume, _stEth, _rageQuitEscrow);
    }

    //
    //  WSTETH
    //
    function _wstEthStorageSetup(WstETHAdapted _wstEth, IStETH _stEth) internal {
        kevm.symbolicStorage(address(_wstEth));
    }

    //
    //  WITHDRAWAL QUEUE
    //
    uint256 constant LASTREQUESTID_SLOT = WithdrawalQueueStorageConstants.STORAGE_LASTREQUESTID_SLOT;
    uint256 constant LASTREQUESTID_OFFSET = WithdrawalQueueStorageConstants.STORAGE_LASTREQUESTID_OFFSET;
    uint256 constant LASTREQUESTID_SIZE = WithdrawalQueueStorageConstants.STORAGE_LASTREQUESTID_SIZE;
    uint256 constant LASTFINALIZEDREQUESTID_SLOT = WithdrawalQueueStorageConstants.STORAGE_LASTFINALIZEDREQUESTID_SLOT;
    uint256 constant LASTFINALIZEDREQUESTID_OFFSET =
        WithdrawalQueueStorageConstants.STORAGE_LASTFINALIZEDREQUESTID_OFFSET;
    uint256 constant LASTFINALIZEDREQUESTID_SIZE = WithdrawalQueueStorageConstants.STORAGE_LASTFINALIZEDREQUESTID_SIZE;
    uint256 constant LOCKEDETHERAMOUNT_SLOT = WithdrawalQueueStorageConstants.STORAGE_LOCKEDETHERAMOUNT_SLOT;
    uint256 constant LOCKEDETHERAMOUNT_OFFSET = WithdrawalQueueStorageConstants.STORAGE_LOCKEDETHERAMOUNT_OFFSET;
    uint256 constant LOCKEDETHERAMOUNT_SIZE = WithdrawalQueueStorageConstants.STORAGE_LOCKEDETHERAMOUNT_SIZE;
    uint256 constant STETH_SLOT = WithdrawalQueueStorageConstants.STORAGE_STETH_SLOT;
    uint256 constant STETH_OFFSET = WithdrawalQueueStorageConstants.STORAGE_STETH_OFFSET;
    uint256 constant STETH_SIZE = WithdrawalQueueStorageConstants.STORAGE_STETH_SIZE;
    uint256 constant OWNERS_SLOT = WithdrawalQueueStorageConstants.STORAGE_OWNERS_SLOT;
    uint256 constant REQUESTS_SLOT = WithdrawalQueueStorageConstants.STORAGE_REQUESTS_SLOT;
    uint256 constant ISCLAIMED_SLOT =
        WithdrawalQueueStorageConstants.STRUCT_WITHDRAWALQUEUEMODEL_WITHDRAWALREQUEST_ISCLAIMED_SLOT;
    uint256 constant ISCLAIMED_OFFSET =
        WithdrawalQueueStorageConstants.STRUCT_WITHDRAWALQUEUEMODEL_WITHDRAWALREQUEST_ISCLAIMED_OFFSET;
    uint256 constant ISCLAIMED_SIZE =
        WithdrawalQueueStorageConstants.STRUCT_WITHDRAWALQUEUEMODEL_WITHDRAWALREQUEST_ISCLAIMED_SIZE;
    uint256 constant OWNER_SLOT =
        WithdrawalQueueStorageConstants.STRUCT_WITHDRAWALQUEUEMODEL_WITHDRAWALREQUEST_OWNER_SLOT;
    uint256 constant OWNER_OFFSET =
        WithdrawalQueueStorageConstants.STRUCT_WITHDRAWALQUEUEMODEL_WITHDRAWALREQUEST_OWNER_OFFSET;
    uint256 constant OWNER_SIZE =
        WithdrawalQueueStorageConstants.STRUCT_WITHDRAWALQUEUEMODEL_WITHDRAWALREQUEST_OWNER_SIZE;

    function _getLastRequestId(WithdrawalQueueModel _withdrawalQueue) internal view returns (uint256) {
        return _loadData(address(_withdrawalQueue), LASTREQUESTID_SLOT, LASTREQUESTID_OFFSET, LASTREQUESTID_SIZE);
    }

    function _getLastFinalizedRequestId(WithdrawalQueueModel _withdrawalQueue) internal view returns (uint256) {
        return _loadData(
            address(_withdrawalQueue),
            LASTFINALIZEDREQUESTID_SLOT,
            LASTFINALIZEDREQUESTID_OFFSET,
            LASTFINALIZEDREQUESTID_SIZE
        );
    }

    function _getRequestIsClaimed(WithdrawalQueueModel _withdrawalQueue, uint256 _requestId) internal returns (bool) {
        return 0
            != _loadMappingData(
                address(_withdrawalQueue), REQUESTS_SLOT, _requestId, ISCLAIMED_SLOT, ISCLAIMED_OFFSET, ISCLAIMED_SIZE
            );
    }

    function _getRequestOwner(WithdrawalQueueModel _withdrawalQueue, uint256 _requestId) internal returns (address) {
        return address(
            uint160(
                _loadMappingData(
                    address(_withdrawalQueue),
                    REQUESTS_SLOT,
                    _requestId,
                    ISCLAIMED_SLOT,
                    ISCLAIMED_OFFSET,
                    ISCLAIMED_SIZE
                )
            )
        );
    }

    function withdrawalQueueStorageSetup(
        WithdrawalQueueModel _withdrawalQueue,
        IStETH _stEth,
        IEscrowBase _escrow
    ) external {
        kevm.symbolicStorage(address(_withdrawalQueue));

        uint256 lastRequestId = freshUInt256("lastRequestId");
        // If we assume that request IDs increase sequentially, it's unlikely tha they will reach this high
        vm.assume(lastRequestId < 2 ** 64);
        uint256 owner = freshUInt160("owner");

        // TODO: Storage clearance, requires maintenance
        _clearSlot(address(_withdrawalQueue), STETH_SLOT);
        _clearMappingSlot(address(_withdrawalQueue), OWNERS_SLOT, lastRequestId + 1, 0);

        _storeData(address(_withdrawalQueue), STETH_SLOT, STETH_OFFSET, STETH_SIZE, uint256(uint160(address(_stEth))));

        _storeData(
            address(_withdrawalQueue), LASTREQUESTID_SLOT, LASTREQUESTID_OFFSET, LASTREQUESTID_SIZE, lastRequestId
        );

        _storeMappingData(address(_withdrawalQueue), OWNERS_SLOT, lastRequestId + 1, 0, 0, 20, owner);

        uint256 lastFinalizedRequestId = freshUInt256("lastFinalizedRequestId");
        _storeData(
            address(_withdrawalQueue),
            LASTFINALIZEDREQUESTID_SLOT,
            LASTFINALIZEDREQUESTID_OFFSET,
            LASTFINALIZEDREQUESTID_SIZE,
            lastFinalizedRequestId
        );

        uint256 lockedEtherAmount = freshUInt256("lockedEtherAmount");
        _storeData(
            address(_withdrawalQueue),
            LOCKEDETHERAMOUNT_SLOT,
            LOCKEDETHERAMOUNT_OFFSET,
            LOCKEDETHERAMOUNT_SIZE,
            lockedEtherAmount
        );
        vm.deal(address(_withdrawalQueue), lockedEtherAmount);
    }

    function withdrawalQueueRequestSetup(WithdrawalQueueModel _withdrawalQueue, uint256 _requestId) external {
        uint256 isClaimed = freshUInt8("isClaimed");
        _storeMappingData(
            address(_withdrawalQueue),
            REQUESTS_SLOT,
            _requestId,
            ISCLAIMED_SLOT,
            ISCLAIMED_OFFSET,
            ISCLAIMED_SIZE,
            isClaimed
        );

        uint256 owner = freshUInt160("owner");
        _storeMappingData(
            address(_withdrawalQueue), REQUESTS_SLOT, _requestId, OWNER_SLOT, OWNER_OFFSET, OWNER_SIZE, owner
        );
    }

    //
    //  DUAL GOVERNANCE
    //
    uint256 constant STATE_SLOT = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_STATE_SLOT;
    uint256 constant STATE_OFFSET = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_STATE_OFFSET;
    uint256 constant STATE_SIZE = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_STATE_SIZE;
    uint256 constant ENTEREDAT_SLOT = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_ENTEREDAT_SLOT;
    uint256 constant ENTEREDAT_OFFSET = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_ENTEREDAT_OFFSET;
    uint256 constant ENTEREDAT_SIZE = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_ENTEREDAT_SIZE;
    uint256 constant ACTIVATEDAT_SLOT =
        DualGovernanceStorageConstants.STORAGE_STATEMACHINE_VETOSIGNALLINGACTIVATEDAT_SLOT;
    uint256 constant ACTIVATEDAT_OFFSET =
        DualGovernanceStorageConstants.STORAGE_STATEMACHINE_VETOSIGNALLINGACTIVATEDAT_OFFSET;
    uint256 constant ACTIVATEDAT_SIZE =
        DualGovernanceStorageConstants.STORAGE_STATEMACHINE_VETOSIGNALLINGACTIVATEDAT_SIZE;
    uint256 constant RAGEQUITROUND_SLOT = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_RAGEQUITROUND_SLOT;
    uint256 constant RAGEQUITROUND_OFFSET = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_RAGEQUITROUND_OFFSET;
    uint256 constant RAGEQUITROUND_SIZE = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_RAGEQUITROUND_SIZE;
    uint256 constant REACTIVATIONTIME_SLOT =
        DualGovernanceStorageConstants.STORAGE_STATEMACHINE_VETOSIGNALLINGREACTIVATIONTIME_SLOT;
    uint256 constant REACTIVATIONTIME_OFFSET =
        DualGovernanceStorageConstants.STORAGE_STATEMACHINE_VETOSIGNALLINGREACTIVATIONTIME_OFFSET;
    uint256 constant REACTIVATIONTIME_SIZE =
        DualGovernanceStorageConstants.STORAGE_STATEMACHINE_VETOSIGNALLINGREACTIVATIONTIME_SIZE;
    uint256 constant EXITEDAT_SLOT =
        DualGovernanceStorageConstants.STORAGE_STATEMACHINE_NORMALORVETOCOOLDOWNEXITEDAT_SLOT;
    uint256 constant EXITEDAT_OFFSET =
        DualGovernanceStorageConstants.STORAGE_STATEMACHINE_NORMALORVETOCOOLDOWNEXITEDAT_OFFSET;
    uint256 constant EXITEDAT_SIZE =
        DualGovernanceStorageConstants.STORAGE_STATEMACHINE_NORMALORVETOCOOLDOWNEXITEDAT_SIZE;
    uint256 constant SIGNALLINGESCROW_SLOT = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_SIGNALLINGESCROW_SLOT;
    uint256 constant SIGNALLINGESCROW_OFFSET =
        DualGovernanceStorageConstants.STORAGE_STATEMACHINE_SIGNALLINGESCROW_OFFSET;
    uint256 constant SIGNALLINGESCROW_SIZE = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_SIGNALLINGESCROW_SIZE;
    uint256 constant RAGEQUITESCROW_SLOT = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_RAGEQUITESCROW_SLOT;
    uint256 constant RAGEQUITESCROW_OFFSET = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_RAGEQUITESCROW_OFFSET;
    uint256 constant RAGEQUITESCROW_SIZE = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_RAGEQUITESCROW_SIZE;
    uint256 constant CONFIGPROVIDER_SLOT = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_CONFIGPROVIDER_SLOT;
    uint256 constant CONFIGPROVIDER_OFFSET = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_CONFIGPROVIDER_OFFSET;
    uint256 constant CONFIGPROVIDER_SIZE = DualGovernanceStorageConstants.STORAGE_STATEMACHINE_CONFIGPROVIDER_SIZE;

    function _getCurrentState(DualGovernance _dualGovernance) internal view returns (uint8) {
        return uint8(_loadData(address(_dualGovernance), STATE_SLOT, STATE_OFFSET, STATE_SIZE));
    }

    function _getEnteredAt(DualGovernance _dualGovernance) internal view returns (uint40) {
        return uint40(_loadData(address(_dualGovernance), ENTEREDAT_SLOT, ENTEREDAT_OFFSET, ENTEREDAT_SIZE));
    }

    function _getVetoSignallingActivationTime(DualGovernance _dualGovernance) internal view returns (uint40) {
        return uint40(_loadData(address(_dualGovernance), ACTIVATEDAT_SLOT, ACTIVATEDAT_OFFSET, ACTIVATEDAT_SIZE));
    }

    function _getRageQuitRound(DualGovernance _dualGovernance) internal view returns (uint8) {
        return uint8(_loadData(address(_dualGovernance), RAGEQUITROUND_SLOT, RAGEQUITROUND_OFFSET, RAGEQUITROUND_SIZE));
    }

    function _getVetoSignallingReactivationTime(DualGovernance _dualGovernance) internal view returns (uint40) {
        return uint40(
            _loadData(address(_dualGovernance), REACTIVATIONTIME_SLOT, REACTIVATIONTIME_OFFSET, REACTIVATIONTIME_SIZE)
        );
    }

    function _getNormalOrVetoCooldownExitedAt(DualGovernance _dualGovernance) internal view returns (uint40) {
        return uint40(_loadData(address(_dualGovernance), EXITEDAT_SLOT, EXITEDAT_OFFSET, EXITEDAT_SIZE));
    }

    function dualGovernanceStorageSetup(
        DualGovernance _dualGovernance,
        IEscrowBase _signallingEscrow,
        IEscrowBase _rageQuitEscrow,
        IDualGovernanceConfigProvider _config
    ) external {
        kevm.symbolicStorage(address(_dualGovernance));

        // TODO: Storage clearance, requires maintenance
        _clearSlot(address(_dualGovernance), 6);
        _clearSlot(address(_dualGovernance), 7);
        _clearSlot(address(_dualGovernance), 8);

        // Slot 6:
        uint256 currentState = freshUInt256("DG_STATE");
        vm.assume(currentState != 0); // Cannot be Unset as dual governance was initialised
        vm.assume(currentState <= 5);
        uint256 enteredAt = freshUInt256("DG_EA");
        vm.assume(enteredAt <= block.timestamp);
        vm.assume(enteredAt < timeUpperBound);
        uint256 vetoSignallingActivationTime = freshUInt256("DG_VSAT");
        vm.assume(vetoSignallingActivationTime <= block.timestamp);
        vm.assume(vetoSignallingActivationTime < timeUpperBound);
        uint256 rageQuitRound = freshUInt256("DG_RQR");
        vm.assume(rageQuitRound < type(uint8).max);

        _storeData(address(_dualGovernance), STATE_SLOT, STATE_OFFSET, STATE_SIZE, currentState);
        _storeData(address(_dualGovernance), ENTEREDAT_SLOT, ENTEREDAT_OFFSET, ENTEREDAT_SIZE, enteredAt);
        _storeData(
            address(_dualGovernance),
            ACTIVATEDAT_SLOT,
            ACTIVATEDAT_OFFSET,
            ACTIVATEDAT_SIZE,
            vetoSignallingActivationTime
        );
        _storeData(
            address(_dualGovernance),
            SIGNALLINGESCROW_SLOT,
            SIGNALLINGESCROW_OFFSET,
            SIGNALLINGESCROW_SIZE,
            uint256(uint160(address(_signallingEscrow)))
        );
        _storeData(
            address(_dualGovernance), RAGEQUITROUND_SLOT, RAGEQUITROUND_OFFSET, RAGEQUITROUND_SIZE, rageQuitRound
        );

        // Slot 7
        uint256 vetoSignallingReactivationTime = freshUInt256("DG_VSRT");
        vm.assume(vetoSignallingReactivationTime <= block.timestamp);
        vm.assume(vetoSignallingReactivationTime < timeUpperBound);
        uint256 normalOrVetoCooldownExitedAt = freshUInt256("DG_NVCEA");
        vm.assume(normalOrVetoCooldownExitedAt <= block.timestamp);
        vm.assume(normalOrVetoCooldownExitedAt < timeUpperBound);

        _storeData(
            address(_dualGovernance),
            REACTIVATIONTIME_SLOT,
            REACTIVATIONTIME_OFFSET,
            REACTIVATIONTIME_SIZE,
            vetoSignallingReactivationTime
        );
        _storeData(
            address(_dualGovernance), EXITEDAT_SLOT, EXITEDAT_OFFSET, EXITEDAT_SIZE, normalOrVetoCooldownExitedAt
        );
        _storeData(
            address(_dualGovernance),
            RAGEQUITESCROW_SLOT,
            RAGEQUITESCROW_OFFSET,
            RAGEQUITESCROW_SIZE,
            uint256(uint160(address(_rageQuitEscrow)))
        );

        // Slot 8
        _storeData(
            address(_dualGovernance),
            CONFIGPROVIDER_SLOT,
            CONFIGPROVIDER_OFFSET,
            CONFIGPROVIDER_SIZE,
            uint256(uint160(address(_config)))
        );
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
        IEscrowBase _signallingEscrow,
        IEscrowBase _rageQuitEscrow,
        IDualGovernanceConfigProvider _config
    ) external {
        this.dualGovernanceStorageSetup(_dualGovernance, _signallingEscrow, _rageQuitEscrow, _config);
        this.dualGovernanceStorageInvariants(Mode.Assume, _dualGovernance);
        this.dualGovernanceAssumeBounds(_dualGovernance);
    }

    //
    //  ESCROW
    //
    uint256 constant ESCROWSTATE_SLOT = EscrowStorageConstants.STORAGE_ESCROWSTATE_STATE_SLOT;
    uint256 constant ESCROWSTATE_OFFSET = EscrowStorageConstants.STORAGE_ESCROWSTATE_STATE_OFFSET;
    uint256 constant ESCROWSTATE_SIZE = EscrowStorageConstants.STORAGE_ESCROWSTATE_STATE_SIZE;
    uint256 constant MINLOCKDURATION_SLOT = EscrowStorageConstants.STORAGE_ESCROWSTATE_MINASSETSLOCKDURATION_SLOT;
    uint256 constant MINLOCKDURATION_OFFSET = EscrowStorageConstants.STORAGE_ESCROWSTATE_MINASSETSLOCKDURATION_OFFSET;
    uint256 constant MINLOCKDURATION_SIZE = EscrowStorageConstants.STORAGE_ESCROWSTATE_MINASSETSLOCKDURATION_SIZE;
    uint256 constant EXTENSIONDURATION_SLOT =
        EscrowStorageConstants.STORAGE_ESCROWSTATE_RAGEQUITEXTENSIONPERIODDURATION_SLOT;
    uint256 constant EXTENSIONDURATION_OFFSET =
        EscrowStorageConstants.STORAGE_ESCROWSTATE_RAGEQUITEXTENSIONPERIODDURATION_OFFSET;
    uint256 constant EXTENSIONDURATION_SIZE =
        EscrowStorageConstants.STORAGE_ESCROWSTATE_RAGEQUITEXTENSIONPERIODDURATION_SIZE;
    uint256 constant EXTENSIONSTARTEDAT_SLOT =
        EscrowStorageConstants.STORAGE_ESCROWSTATE_RAGEQUITEXTENSIONPERIODSTARTEDAT_SLOT;
    uint256 constant EXTENSIONSTARTEDAT_OFFSET =
        EscrowStorageConstants.STORAGE_ESCROWSTATE_RAGEQUITEXTENSIONPERIODSTARTEDAT_OFFSET;
    uint256 constant EXTENSIONSTARTEDAT_SIZE =
        EscrowStorageConstants.STORAGE_ESCROWSTATE_RAGEQUITEXTENSIONPERIODSTARTEDAT_SIZE;
    uint256 constant WITHDRAWALSDELAY_SLOT = EscrowStorageConstants.STORAGE_ESCROWSTATE_RAGEQUITETHWITHDRAWALSDELAY_SLOT;
    uint256 constant WITHDRAWALSDELAY_OFFSET =
        EscrowStorageConstants.STORAGE_ESCROWSTATE_RAGEQUITETHWITHDRAWALSDELAY_OFFSET;
    uint256 constant WITHDRAWALSDELAY_SIZE = EscrowStorageConstants.STORAGE_ESCROWSTATE_RAGEQUITETHWITHDRAWALSDELAY_SIZE;
    uint256 constant LOCKEDSHARES_SLOT = EscrowStorageConstants.STORAGE_ACCOUNTING_STETHTOTALS_LOCKEDSHARES_SLOT;
    uint256 constant LOCKEDSHARES_OFFSET = EscrowStorageConstants.STORAGE_ACCOUNTING_STETHTOTALS_LOCKEDSHARES_OFFSET;
    uint256 constant LOCKEDSHARES_SIZE = EscrowStorageConstants.STORAGE_ACCOUNTING_STETHTOTALS_LOCKEDSHARES_SIZE;
    uint256 constant CLAIMEDETH_SLOT = EscrowStorageConstants.STORAGE_ACCOUNTING_STETHTOTALS_CLAIMEDETH_SLOT;
    uint256 constant CLAIMEDETH_OFFSET = EscrowStorageConstants.STORAGE_ACCOUNTING_STETHTOTALS_CLAIMEDETH_OFFSET;
    uint256 constant CLAIMEDETH_SIZE = EscrowStorageConstants.STORAGE_ACCOUNTING_STETHTOTALS_CLAIMEDETH_SIZE;
    uint256 constant UNFINALIZEDSHARES_SLOT =
        EscrowStorageConstants.STORAGE_ACCOUNTING_UNSTETHTOTALS_UNFINALIZEDSHARES_SLOT;
    uint256 constant UNFINALIZEDSHARES_OFFSET =
        EscrowStorageConstants.STORAGE_ACCOUNTING_UNSTETHTOTALS_UNFINALIZEDSHARES_OFFSET;
    uint256 constant UNFINALIZEDSHARES_SIZE =
        EscrowStorageConstants.STORAGE_ACCOUNTING_UNSTETHTOTALS_UNFINALIZEDSHARES_SIZE;
    uint256 constant FINALIZEDETH_SLOT = EscrowStorageConstants.STORAGE_ACCOUNTING_UNSTETHTOTALS_FINALIZEDETH_SLOT;
    uint256 constant FINALIZEDETH_OFFSET = EscrowStorageConstants.STORAGE_ACCOUNTING_UNSTETHTOTALS_FINALIZEDETH_OFFSET;
    uint256 constant FINALIZEDETH_SIZE = EscrowStorageConstants.STORAGE_ACCOUNTING_UNSTETHTOTALS_FINALIZEDETH_SIZE;
    uint256 constant ASSETS_SLOT = EscrowStorageConstants.STORAGE_ACCOUNTING_ASSETS_SLOT;
    uint256 constant LASTASSETSLOCK_SLOT = EscrowStorageConstants.STRUCT_HOLDERASSETS_LASTASSETSLOCKTIMESTAMP_SLOT;
    uint256 constant LASTASSETSLOCK_OFFSET = EscrowStorageConstants.STRUCT_HOLDERASSETS_LASTASSETSLOCKTIMESTAMP_OFFSET;
    uint256 constant LASTASSETSLOCK_SIZE = EscrowStorageConstants.STRUCT_HOLDERASSETS_LASTASSETSLOCKTIMESTAMP_SIZE;
    uint256 constant STETHSHARES_SLOT = EscrowStorageConstants.STRUCT_HOLDERASSETS_STETHLOCKEDSHARES_SLOT;
    uint256 constant STETHSHARES_OFFSET = EscrowStorageConstants.STRUCT_HOLDERASSETS_STETHLOCKEDSHARES_OFFSET;
    uint256 constant STETHSHARES_SIZE = EscrowStorageConstants.STRUCT_HOLDERASSETS_STETHLOCKEDSHARES_SIZE;
    uint256 constant UNSTETHSHARES_SLOT = EscrowStorageConstants.STRUCT_HOLDERASSETS_UNSTETHLOCKEDSHARES_SLOT;
    uint256 constant UNSTETHSHARES_OFFSET = EscrowStorageConstants.STRUCT_HOLDERASSETS_UNSTETHLOCKEDSHARES_OFFSET;
    uint256 constant UNSTETHSHARES_SIZE = EscrowStorageConstants.STRUCT_HOLDERASSETS_UNSTETHLOCKEDSHARES_SIZE;
    uint256 constant UNSTETHIDSLENGTH_SLOT = EscrowStorageConstants.STRUCT_HOLDERASSETS_UNSTETHIDS_SLOT;
    uint256 constant UNSTETHIDSLENGTH_OFFSET = EscrowStorageConstants.STRUCT_HOLDERASSETS_UNSTETHIDS_OFFSET;
    uint256 constant UNSTETHIDSLENGTH_SIZE = EscrowStorageConstants.STRUCT_HOLDERASSETS_UNSTETHIDS_SIZE;
    uint256 constant BATCHESLENGTH_SLOT = EscrowStorageConstants.STORAGE_BATCHESQUEUE_BATCHES_SLOT;
    uint256 constant BATCHESLENGTH_OFFSET = EscrowStorageConstants.STORAGE_BATCHESQUEUE_BATCHES_OFFSET;
    uint256 constant BATCHESLENGTH_SIZE = EscrowStorageConstants.STORAGE_BATCHESQUEUE_BATCHES_SIZE;
    uint256 constant BATCHESQUEUESTATE_SLOT = EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_STATE_SLOT;
    uint256 constant BATCHESQUEUESTATE_OFFSET = EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_STATE_OFFSET;
    uint256 constant BATCHESQUEUESTATE_SIZE = EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_STATE_SIZE;
    uint256 constant TOTALUNSTETHIDSCOUNT_SLOT =
        EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_TOTALUNSTETHIDSCOUNT_SLOT;
    uint256 constant TOTALUNSTETHIDSCOUNT_OFFSET =
        EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_TOTALUNSTETHIDSCOUNT_OFFSET;
    uint256 constant TOTALUNSTETHIDSCOUNT_SIZE =
        EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_TOTALUNSTETHIDSCOUNT_SIZE;
    uint256 constant TOTALUNSTETHIDSCLAIMED_SLOT =
        EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_TOTALUNSTETHIDSCLAIMED_SLOT;
    uint256 constant TOTALUNSTETHIDSCLAIMED_OFFSET =
        EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_TOTALUNSTETHIDSCLAIMED_OFFSET;
    uint256 constant TOTALUNSTETHIDSCLAIMED_SIZE =
        EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_TOTALUNSTETHIDSCLAIMED_SIZE;
    uint256 constant LASTCLAIMEDBATCHINDEX_SLOT =
        EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_LASTCLAIMEDBATCHINDEX_SLOT;
    uint256 constant LASTCLAIMEDBATCHINDEX_OFFSET =
        EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_LASTCLAIMEDBATCHINDEX_OFFSET;
    uint256 constant LASTCLAIMEDBATCHINDEX_SIZE =
        EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_LASTCLAIMEDBATCHINDEX_SIZE;
    uint256 constant LASTCLAIMEDUNSTETHIDINDEX_SLOT =
        EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_LASTCLAIMEDUNSTETHIDINDEX_SLOT;
    uint256 constant LASTCLAIMEDUNSTETHIDINDEX_OFFSET =
        EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_LASTCLAIMEDUNSTETHIDINDEX_OFFSET;
    uint256 constant LASTCLAIMEDUNSTETHIDINDEX_SIZE =
        EscrowStorageConstants.STORAGE_BATCHESQUEUE_INFO_LASTCLAIMEDUNSTETHIDINDEX_SIZE;
    uint256 constant FIRSTUNSTETHID_SLOT =
        EscrowStorageConstants.STRUCT_WITHDRAWALSBATCHESQUEUE_SEQUENTIALBATCH_FIRSTUNSTETHID_SLOT;
    uint256 constant FIRSTUNSTETHID_OFFSET =
        EscrowStorageConstants.STRUCT_WITHDRAWALSBATCHESQUEUE_SEQUENTIALBATCH_FIRSTUNSTETHID_OFFSET;
    uint256 constant FIRSTUNSTETHID_SIZE =
        EscrowStorageConstants.STRUCT_WITHDRAWALSBATCHESQUEUE_SEQUENTIALBATCH_FIRSTUNSTETHID_SIZE;
    uint256 constant LASTUNSTETHID_SLOT =
        EscrowStorageConstants.STRUCT_WITHDRAWALSBATCHESQUEUE_SEQUENTIALBATCH_LASTUNSTETHID_SLOT;
    uint256 constant LASTUNSTETHID_OFFSET =
        EscrowStorageConstants.STRUCT_WITHDRAWALSBATCHESQUEUE_SEQUENTIALBATCH_LASTUNSTETHID_OFFSET;
    uint256 constant LASTUNSTETHID_SIZE =
        EscrowStorageConstants.STRUCT_WITHDRAWALSBATCHESQUEUE_SEQUENTIALBATCH_LASTUNSTETHID_SIZE;
    uint256 constant UNSTETHRECORDS_SLOT = EscrowStorageConstants.STORAGE_ACCOUNTING_UNSTETHRECORDS_SLOT;
    uint256 constant UNSTETHRECORDSTATUS_SLOT = EscrowStorageConstants.STRUCT_UNSTETHRECORD_STATUS_SLOT;
    uint256 constant UNSTETHRECORDSTATUS_OFFSET = EscrowStorageConstants.STRUCT_UNSTETHRECORD_STATUS_OFFSET;
    uint256 constant UNSTETHRECORDSTATUS_SIZE = EscrowStorageConstants.STRUCT_UNSTETHRECORD_STATUS_SIZE;

    function _getCurrentState(IEscrowBase _escrow) internal view returns (uint8) {
        return uint8(_loadData(address(_escrow), ESCROWSTATE_SLOT, ESCROWSTATE_OFFSET, ESCROWSTATE_SIZE));
    }

    function _getMinAssetsLockDuration(IEscrowBase _escrow) internal view returns (uint32) {
        return uint32(_loadData(address(_escrow), MINLOCKDURATION_SLOT, MINLOCKDURATION_OFFSET, MINLOCKDURATION_SIZE));
    }

    function _getRageQuitExtensionPeriodDuration(IEscrowBase _escrow) internal view returns (uint32) {
        return uint32(
            _loadData(address(_escrow), EXTENSIONDURATION_SLOT, EXTENSIONDURATION_OFFSET, EXTENSIONDURATION_SIZE)
        );
    }

    function _getRageQuitExtensionPeriodStartedAt(IEscrowBase _escrow) internal view returns (uint40) {
        return uint40(
            _loadData(address(_escrow), EXTENSIONSTARTEDAT_SLOT, EXTENSIONSTARTEDAT_OFFSET, EXTENSIONSTARTEDAT_SIZE)
        );
    }

    function _getRageQuitEthWithdrawalsDelay(IEscrowBase _escrow) internal view returns (uint32) {
        return
            uint32(_loadData(address(_escrow), WITHDRAWALSDELAY_SLOT, WITHDRAWALSDELAY_OFFSET, WITHDRAWALSDELAY_SIZE));
    }

    function _getTotalStEthLockedShares(IEscrowBase _escrow) internal view returns (uint128) {
        return uint128(_loadData(address(_escrow), LOCKEDSHARES_SLOT, LOCKEDSHARES_OFFSET, LOCKEDSHARES_SIZE));
    }

    function _getClaimedEth(IEscrowBase _escrow) internal view returns (uint128) {
        return uint128(_loadData(address(_escrow), CLAIMEDETH_SLOT, CLAIMEDETH_OFFSET, CLAIMEDETH_SIZE));
    }

    function _getUnfinalizedShares(IEscrowBase _escrow) internal view returns (uint128) {
        return uint128(
            _loadData(address(_escrow), UNFINALIZEDSHARES_SLOT, UNFINALIZEDSHARES_OFFSET, UNFINALIZEDSHARES_SIZE)
        );
    }

    function _getFinalizedEth(IEscrowBase _escrow) internal view returns (uint128) {
        return uint128(_loadData(address(_escrow), FINALIZEDETH_SLOT, FINALIZEDETH_OFFSET, FINALIZEDETH_SIZE));
    }

    function _getLastAssetsLockTimestamp(IEscrowBase _escrow, address _vetoer) internal view returns (uint40) {
        uint256 key = uint256(uint160(_vetoer));
        return uint40(
            _loadMappingData(
                address(_escrow), ASSETS_SLOT, key, LASTASSETSLOCK_SLOT, LASTASSETSLOCK_OFFSET, LASTASSETSLOCK_SIZE
            )
        );
    }

    function _getStEthLockedShares(IEscrowBase _escrow, address _vetoer) internal view returns (uint128) {
        uint256 key = uint256(uint160(_vetoer));
        return uint128(
            _loadMappingData(address(_escrow), ASSETS_SLOT, key, STETHSHARES_SLOT, STETHSHARES_OFFSET, STETHSHARES_SIZE)
        );
    }

    function _getBatchesQueueStatus(IEscrowBase _escrow) internal view returns (uint8) {
        return
            uint8(_loadData(address(_escrow), BATCHESQUEUESTATE_SLOT, BATCHESQUEUESTATE_OFFSET, BATCHESQUEUESTATE_SIZE));
    }

    function _getBatchesLength(IEscrowBase _escrow) internal view returns (uint256) {
        return _loadData(address(_escrow), BATCHESLENGTH_SLOT, BATCHESLENGTH_OFFSET, BATCHESLENGTH_SIZE);
    }

    function _getLastClaimedBatchSlot(IEscrowBase _escrow) internal view returns (uint256) {
        return _getBatchSlot(_escrow, _getLastClaimedBatchIndex(_escrow));
    }

    function _getLastWithdrawalsBatchSlot(IEscrowBase _escrow) internal view returns (uint256) {
        return _getBatchSlot(_escrow, _getBatchesLength(_escrow) - 1);
    }

    function _getBatchSlot(IEscrowBase _escrow, uint256 _batchIndex) internal view returns (uint256) {
        uint256 batchesDataSlot = uint256(keccak256(abi.encode(BATCHESLENGTH_SLOT)));
        // SequentialBatch struct occupies 2 slots
        // TODO: replace with constant
        uint256 batchStructSize = 2;
        return batchesDataSlot + batchStructSize * _batchIndex;
    }

    function _getFirstUnstEthId(IEscrowBase _escrow, uint256 _batchIndex) internal view returns (uint256) {
        uint256 batchSlot = _getBatchSlot(_escrow, _batchIndex);
        return _loadData(address(_escrow), batchSlot + FIRSTUNSTETHID_SLOT, FIRSTUNSTETHID_OFFSET, FIRSTUNSTETHID_SIZE);
    }

    function _getLastUnstEthId(IEscrowBase _escrow, uint256 _batchIndex) internal view returns (uint256) {
        uint256 batchSlot = _getBatchSlot(_escrow, _batchIndex);
        return _loadData(address(_escrow), batchSlot + LASTUNSTETHID_SLOT, LASTUNSTETHID_OFFSET, LASTUNSTETHID_SIZE);
    }

    function _getLastClaimedBatchIndex(IEscrowBase _escrow) internal view returns (uint56) {
        return uint56(
            _loadData(
                address(_escrow), LASTCLAIMEDBATCHINDEX_SLOT, LASTCLAIMEDBATCHINDEX_OFFSET, LASTCLAIMEDBATCHINDEX_SIZE
            )
        );
    }

    function _getLastClaimedUnstEthIdIndex(IEscrowBase _escrow) internal view returns (uint64) {
        return uint64(
            _loadData(
                address(_escrow),
                LASTCLAIMEDUNSTETHIDINDEX_SLOT,
                LASTCLAIMEDUNSTETHIDINDEX_OFFSET,
                LASTCLAIMEDUNSTETHIDINDEX_SIZE
            )
        );
    }

    function _getTotalUnstEthIdsCount(IEscrowBase _escrow) internal view returns (uint64) {
        return uint64(
            _loadData(
                address(_escrow), TOTALUNSTETHIDSCOUNT_SLOT, TOTALUNSTETHIDSCOUNT_OFFSET, TOTALUNSTETHIDSCOUNT_SIZE
            )
        );
    }

    function _getTotalUnstEthIdsClaimed(IEscrowBase _escrow) internal view returns (uint64) {
        return uint64(
            _loadData(
                address(_escrow),
                TOTALUNSTETHIDSCLAIMED_SLOT,
                TOTALUNSTETHIDSCLAIMED_OFFSET,
                TOTALUNSTETHIDSCLAIMED_SIZE
            )
        );
    }

    function _getUnstEthRecordStatus(IEscrowBase _escrow, uint256 _requestId) internal view returns (uint8) {
        return uint8(
            _loadMappingData(
                address(_escrow),
                UNSTETHRECORDS_SLOT,
                _requestId,
                UNSTETHRECORDSTATUS_SLOT,
                UNSTETHRECORDSTATUS_OFFSET,
                UNSTETHRECORDSTATUS_SIZE
            )
        );
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
        Escrow.VetoerDetails memory vetoerDetails = escrow.getVetoerDetails(user);
        Escrow.SignallingEscrowDetails memory signallingEscrowDetails = escrow.getSignallingEscrowDetails();
        StETHModel stEth = StETHModel(address(escrow.ST_ETH()));

        ar.allowance = stEth.allowance(user, address(escrow));
        ar.userBalance = stEth.balanceOf(user);
        ar.escrowBalance = stEth.balanceOf(address(escrow));
        ar.userShares = stEth.sharesOf(user);
        ar.escrowShares = stEth.sharesOf(address(escrow));
        ar.userSharesLocked = SharesValue.unwrap(vetoerDetails.stETHLockedShares);
        ar.totalSharesLocked = SharesValue.unwrap(signallingEscrowDetails.totalStETHLockedShares);
        ar.totalEth = stEth.getPooledEthByShares(ar.totalSharesLocked);
        ar.userUnstEthLockedShares = SharesValue.unwrap(vetoerDetails.unstETHLockedShares);
        ar.unfinalizedShares = SharesValue.unwrap(signallingEscrowDetails.totalUnstETHUnfinalizedShares);
        ar.userLastLockedTime = Timestamp.wrap(uint40(_getLastAssetsLockTimestamp(escrow, user)));
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

    function escrowStorageSetup(IEscrowBase _escrow, EscrowSt _currentState) external {
        kevm.symbolicStorage(address(_escrow));

        // TODO: Storage clearance, requires maintenance
        _clearSlot(address(_escrow), 0);

        // Slot 0
        {
            _storeData(address(_escrow), ESCROWSTATE_SLOT, ESCROWSTATE_OFFSET, ESCROWSTATE_SIZE, uint256(_currentState));

            uint256 minAssetsLockDuration = freshUInt256("ES_MALD");
            vm.assume(minAssetsLockDuration < 2 ** 32);
            vm.assume(minAssetsLockDuration <= block.timestamp);
            _storeData(
                address(_escrow),
                MINLOCKDURATION_SLOT,
                MINLOCKDURATION_OFFSET,
                MINLOCKDURATION_SIZE,
                minAssetsLockDuration
            );

            if (_currentState == EscrowSt.RageQuitEscrow) {
                uint256 rageQuitExtensionPeriodDuration = freshUInt256("ES_RQEPD");
                vm.assume(rageQuitExtensionPeriodDuration < 2 ** 32);
                vm.assume(rageQuitExtensionPeriodDuration <= block.timestamp);
                uint256 rageQuitExtensionPeriodStartedAt = freshUInt256("ES_RQEPS");
                vm.assume(rageQuitExtensionPeriodStartedAt <= block.timestamp);
                vm.assume(rageQuitExtensionPeriodStartedAt < timeUpperBound);
                uint256 rageQuitEthWithdrawalsDelay = freshUInt256("ES_RQEWD");
                vm.assume(rageQuitEthWithdrawalsDelay < 2 ** 32);
                vm.assume(rageQuitEthWithdrawalsDelay <= block.timestamp);

                _storeData(
                    address(_escrow),
                    EXTENSIONDURATION_SLOT,
                    EXTENSIONDURATION_OFFSET,
                    EXTENSIONDURATION_SIZE,
                    rageQuitExtensionPeriodDuration
                );
                _storeData(
                    address(_escrow),
                    EXTENSIONSTARTEDAT_SLOT,
                    EXTENSIONSTARTEDAT_OFFSET,
                    EXTENSIONSTARTEDAT_SIZE,
                    rageQuitExtensionPeriodStartedAt
                );
                _storeData(
                    address(_escrow),
                    WITHDRAWALSDELAY_SLOT,
                    WITHDRAWALSDELAY_OFFSET,
                    WITHDRAWALSDELAY_SIZE,
                    rageQuitEthWithdrawalsDelay
                );
            } else {
                _storeData(
                    address(_escrow), EXTENSIONDURATION_SLOT, EXTENSIONDURATION_OFFSET, EXTENSIONDURATION_SIZE, 0
                );
                _storeData(
                    address(_escrow), EXTENSIONSTARTEDAT_SLOT, EXTENSIONSTARTEDAT_OFFSET, EXTENSIONSTARTEDAT_SIZE, 0
                );
                _storeData(address(_escrow), WITHDRAWALSDELAY_SLOT, WITHDRAWALSDELAY_OFFSET, WITHDRAWALSDELAY_SIZE, 0);
            }
        }

        // Slot 1
        {
            uint256 lockedShares = freshUInt256("ES_LSH");
            vm.assume(lockedShares < ethUpperBound);
            uint256 claimedEth = freshUInt256("ES_CETH");
            vm.assume(claimedEth < ethUpperBound);

            _storeData(address(_escrow), LOCKEDSHARES_SLOT, LOCKEDSHARES_OFFSET, LOCKEDSHARES_SIZE, lockedShares);
            _storeData(address(_escrow), CLAIMEDETH_SLOT, CLAIMEDETH_OFFSET, CLAIMEDETH_SIZE, claimedEth);
        }

        // Slot 2
        {
            uint256 unfinalizedShares = freshUInt256("ES_USH");
            vm.assume(unfinalizedShares < ethUpperBound);
            uint256 finalizedEth = freshUInt256("ES_FETH");
            vm.assume(finalizedEth < ethUpperBound);

            _storeData(
                address(_escrow),
                UNFINALIZEDSHARES_SLOT,
                UNFINALIZEDSHARES_OFFSET,
                UNFINALIZEDSHARES_SIZE,
                unfinalizedShares
            );
            _storeData(address(_escrow), FINALIZEDETH_SLOT, FINALIZEDETH_OFFSET, FINALIZEDETH_SIZE, finalizedEth);
        }
        // Slot 5
        if (_currentState == EscrowSt.RageQuitEscrow) {
            uint256 batchesQueueStatus = freshUInt256("ES_BQS");
            vm.assume(batchesQueueStatus <= 2);
            _storeData(
                address(_escrow),
                BATCHESQUEUESTATE_SLOT,
                BATCHESQUEUESTATE_OFFSET,
                BATCHESQUEUESTATE_SIZE,
                batchesQueueStatus
            );
        } else {
            _storeData(address(_escrow), BATCHESQUEUESTATE_SLOT, BATCHESQUEUESTATE_OFFSET, BATCHESQUEUESTATE_SIZE, 0);
        }

        uint256 lastClaimedBatchIndex = freshUInt56("lastClaimedBatchIndex");
        _storeData(
            address(_escrow),
            LASTCLAIMEDBATCHINDEX_SLOT,
            LASTCLAIMEDBATCHINDEX_OFFSET,
            LASTCLAIMEDBATCHINDEX_SIZE,
            lastClaimedBatchIndex
        );

        // TODO: Refactor this into its own function
        {
            uint256 lastClaimedBatchSlot = _getBatchSlot(_escrow, lastClaimedBatchIndex);
            uint256 firstUnstEthId = freshUInt256("firstUnstEthId");
            _storeData(
                address(_escrow),
                lastClaimedBatchSlot + FIRSTUNSTETHID_SLOT,
                FIRSTUNSTETHID_OFFSET,
                FIRSTUNSTETHID_SIZE,
                firstUnstEthId
            );
            uint256 lastUnstEthId = freshUInt256("lastUnstEthId");
            _storeData(
                address(_escrow),
                lastClaimedBatchSlot + LASTUNSTETHID_SLOT,
                LASTUNSTETHID_OFFSET,
                LASTUNSTETHID_SIZE,
                lastUnstEthId
            );
        }
        {
            uint256 nextBatchSlot = _getBatchSlot(_escrow, lastClaimedBatchIndex + 1);
            uint256 firstUnstEthId = freshUInt256("firstUnstEthId");
            _storeData(
                address(_escrow),
                nextBatchSlot + FIRSTUNSTETHID_SLOT,
                FIRSTUNSTETHID_OFFSET,
                FIRSTUNSTETHID_SIZE,
                firstUnstEthId
            );
            uint256 lastUnstEthId = freshUInt256("lastUnstEthId");
            _storeData(
                address(_escrow),
                nextBatchSlot + LASTUNSTETHID_SLOT,
                LASTUNSTETHID_OFFSET,
                LASTUNSTETHID_SIZE,
                lastUnstEthId
            );
        }

        uint256 lastClaimedUnstEthIdIndex = freshUInt64("lastClaimedUnstEthIdIndex");
        _storeData(
            address(_escrow),
            LASTCLAIMEDUNSTETHIDINDEX_SLOT,
            LASTCLAIMEDUNSTETHIDINDEX_OFFSET,
            LASTCLAIMEDUNSTETHIDINDEX_SIZE,
            lastClaimedUnstEthIdIndex
        );

        uint256 totalUnstEthIdsCount = freshUInt64("totalUnstEthIdsCount");
        _storeData(
            address(_escrow),
            TOTALUNSTETHIDSCOUNT_SLOT,
            TOTALUNSTETHIDSCOUNT_OFFSET,
            TOTALUNSTETHIDSCOUNT_SIZE,
            totalUnstEthIdsCount
        );

        uint256 totalUnstEthIdsClaimed = freshUInt64("totalUnstEthIdsClaimed");
        _storeData(
            address(_escrow),
            TOTALUNSTETHIDSCLAIMED_SLOT,
            TOTALUNSTETHIDSCLAIMED_OFFSET,
            TOTALUNSTETHIDSCLAIMED_SIZE,
            totalUnstEthIdsClaimed
        );

        // Slot 6
        if (_currentState == EscrowSt.RageQuitEscrow) {
            uint256 batchesQueueLength = freshUInt256("ES_BQL");
            vm.assume(0 < batchesQueueLength);
            vm.assume(batchesQueueLength < 2 ** 64);
            _storeData(
                address(_escrow), BATCHESLENGTH_SLOT, BATCHESLENGTH_OFFSET, BATCHESLENGTH_SIZE, batchesQueueLength
            );

            uint256 lastWithdrawalsBatchSlot = _getBatchSlot(_escrow, batchesQueueLength - 1);
            uint256 firstUnstEthId = freshUInt256("firstUnstEthId");
            _storeData(
                address(_escrow),
                lastWithdrawalsBatchSlot + FIRSTUNSTETHID_SLOT,
                FIRSTUNSTETHID_OFFSET,
                FIRSTUNSTETHID_SIZE,
                firstUnstEthId
            );
            uint256 lastUnstEthId = freshUInt256("lastUnstEthId");
            _storeData(
                address(_escrow),
                lastWithdrawalsBatchSlot + LASTUNSTETHID_SLOT,
                LASTUNSTETHID_OFFSET,
                LASTUNSTETHID_SIZE,
                lastUnstEthId
            );
        } else {
            _storeData(address(_escrow), BATCHESLENGTH_SLOT, BATCHESLENGTH_OFFSET, BATCHESLENGTH_SIZE, 0);
        }
    }

    function escrowUserSetup(IEscrowBase _escrow, address _user) external {
        uint256 key = uint256(uint160(_user));
        uint256 lastAssetsLockTimestamp = freshUInt40("ES_LALT");
        vm.assume(lastAssetsLockTimestamp <= block.timestamp);
        vm.assume(lastAssetsLockTimestamp < timeUpperBound);
        _storeMappingData(
            address(_escrow),
            ASSETS_SLOT,
            key,
            LASTASSETSLOCK_SLOT,
            LASTASSETSLOCK_OFFSET,
            LASTASSETSLOCK_SIZE,
            lastAssetsLockTimestamp
        );
        uint256 stETHLockedShares = freshUInt128("ES_ST_LSH");
        vm.assume(stETHLockedShares < ethUpperBound);
        _storeMappingData(
            address(_escrow),
            ASSETS_SLOT,
            key,
            STETHSHARES_SLOT,
            STETHSHARES_OFFSET,
            STETHSHARES_SIZE,
            stETHLockedShares
        );
        uint256 unstEthLockedShares = freshUInt128("ES_UNST_LSH");
        vm.assume(unstEthLockedShares < ethUpperBound);
        _storeMappingData(
            address(_escrow),
            ASSETS_SLOT,
            key,
            UNSTETHSHARES_SLOT,
            UNSTETHSHARES_OFFSET,
            UNSTETHSHARES_SIZE,
            unstEthLockedShares
        );
        uint256 unstEthIdsLength = freshUInt256("ES_UNST_IL");
        vm.assume(unstEthIdsLength < type(uint32).max);
        _storeMappingData(
            address(_escrow),
            ASSETS_SLOT,
            key,
            UNSTETHIDSLENGTH_SLOT,
            UNSTETHIDSLENGTH_OFFSET,
            UNSTETHIDSLENGTH_SIZE,
            unstEthIdsLength
        );
    }

    function escrowWithdrawalQueueSetup(IEscrowBase _escrow, WithdrawalQueueModel _withdrawalQueue) external {
        uint256 lastRequestId = _getLastRequestId(_withdrawalQueue);
        uint256 unstEthRecordStatus = freshUInt256("ES_UNST_RS");
        vm.assume(unstEthRecordStatus < 5);
        _storeMappingData(
            address(_escrow),
            UNSTETHRECORDS_SLOT,
            lastRequestId + 1,
            UNSTETHRECORDSTATUS_SLOT,
            UNSTETHRECORDSTATUS_OFFSET,
            UNSTETHRECORDSTATUS_SIZE,
            unstEthRecordStatus
        );
    }

    function escrowStorageInvariants(Mode mode, IEscrowBase _escrow) external {
        uint8 batchesQueueStatus = _getBatchesQueueStatus(_escrow);
        uint32 rageQuitEthWithdrawalsDelay = _getRageQuitEthWithdrawalsDelay(_escrow);
        uint32 rageQuitExtensionPeriodDuration = _getRageQuitExtensionPeriodDuration(_escrow);
        uint40 rageQuitExtensionPeriodStartedAt = _getRageQuitExtensionPeriodStartedAt(_escrow);

        _establish(mode, batchesQueueStatus <= 2);
        _establish(mode, rageQuitEthWithdrawalsDelay <= block.timestamp);
        _establish(mode, rageQuitExtensionPeriodDuration <= block.timestamp);
        _establish(mode, rageQuitExtensionPeriodStartedAt <= block.timestamp);
    }

    function escrowAssumeBounds(IEscrowBase _escrow, EscrowSt _currentState) external {
        if (_currentState == EscrowSt.SignallingEscrow) {
            // Assume getRageQuitSupport() doesn´t overflow
            uint256 finalizedEth = _getFinalizedEth(_escrow);
            uint256 unfinalizedShares = _getUnfinalizedShares(_escrow) + _getTotalStEthLockedShares(_escrow);
            IStETH stEth = Escrow(payable(address(_escrow))).ST_ETH();
            uint256 numerator = stEth.getPooledEthByShares(unfinalizedShares) + finalizedEth;
            uint256 denominator = stEth.totalSupply() + finalizedEth;
            vm.assume(1e18 * numerator / denominator <= type(uint128).max);
        }
    }

    function escrowInitializeStorage(IEscrowBase _escrow, EscrowSt _currentState) external {
        this.escrowStorageSetup(_escrow, _currentState);
        this.escrowStorageInvariants(Mode.Assume, _escrow);
        this.escrowAssumeBounds(_escrow, _currentState);
    }

    function signallingEscrowStorageInvariants(Mode mode, IEscrowBase _signallingEscrow) external {
        uint32 rageQuitEthWithdrawalsDelay = _getRageQuitEthWithdrawalsDelay(_signallingEscrow);
        uint32 rageQuitExtensionPeriodDuration = _getRageQuitExtensionPeriodDuration(_signallingEscrow);
        uint40 rageQuitExtensionPeriodStartedAt = _getRageQuitExtensionPeriodStartedAt(_signallingEscrow);
        uint8 batchesQueueStatus = _getBatchesQueueStatus(_signallingEscrow);

        _establish(mode, rageQuitEthWithdrawalsDelay == 0);
        _establish(mode, rageQuitExtensionPeriodDuration == 0);
        _establish(mode, rageQuitExtensionPeriodStartedAt == 0);
        _establish(mode, batchesQueueStatus == uint8(WithdrawalsBatchesQueueState.NotInitialized));
    }

    function signallingEscrowInitializeStorage(IEscrowBase _signallingEscrow) external {
        this.escrowInitializeStorage(_signallingEscrow, EscrowSt.SignallingEscrow);
        this.signallingEscrowStorageInvariants(Mode.Assume, _signallingEscrow);
    }

    function rageQuitEscrowStorageInvariants(Mode mode, IEscrowBase _rageQuitEscrow) external {
        uint8 batchesQueueStatus = _getBatchesQueueStatus(_rageQuitEscrow);

        _establish(mode, batchesQueueStatus != uint8(WithdrawalsBatchesQueueState.NotInitialized));
    }

    function rageQuitEscrowInitializeStorage(IEscrowBase _rageQuitEscrow) external {
        this.escrowInitializeStorage(_rageQuitEscrow, EscrowSt.RageQuitEscrow);
        this.rageQuitEscrowStorageInvariants(Mode.Assume, _rageQuitEscrow);
    }
}
