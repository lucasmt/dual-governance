pragma solidity 0.8.26;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import "contracts/ImmutableDualGovernanceConfigProvider.sol";
import "contracts/DualGovernance.sol";
import "contracts/EmergencyProtectedTimelock.sol";
import "contracts/Escrow.sol";

import {Status, ExecutableProposals as Proposals} from "contracts/libraries/ExecutableProposals.sol";
import {DualGovernanceConfig} from "contracts/libraries/DualGovernanceConfig.sol";
import {addTo, Duration, Durations} from "contracts/types/Duration.sol";
import {Timestamp, Timestamps} from "contracts/types/Timestamp.sol";

import {DualGovernanceSetUp} from "test/kontrol/DualGovernanceSetUp.sol";

contract ProposalOperationsSetup is DualGovernanceSetUp {
    DualGovernance auxDualGovernance;
    EmergencyProtectedTimelock auxTimelock;
    Escrow auxSignallingEscrow;
    Escrow auxRageQuitEscrow;

    // ?STORAGE3
    // ?WORD21: lastCancelledProposalId
    // ?WORD22: proposalsLength
    // ?WORD23: protectedTill
    // ?WORD24: emergencyModeEndsAfter
    function _timelockStorageSetup(DualGovernance _dualGovernance, EmergencyProtectedTimelock _timelock) public {
        //
        uint256 governance = uint256(uint160(address(_dualGovernance)));
        _storeData(address(_timelock), 0, 0, 20, governance);
        //
        uint256 afterSubmitDelay = kevm.freshUInt(4);
        _storeData(address(_timelock), 0, 20, 4, afterSubmitDelay);
        //
        uint256 afterScheduleDelay = kevm.freshUInt(4);
        _storeData(address(_timelock), 0, 24, 4, afterScheduleDelay);
        //
        uint256 proposalsCount = kevm.freshUInt(8);
        vm.assume(proposalsCount < type(uint64).max);
        _storeData(address(_timelock), 1, 0, 8, proposalsCount);
        //
        uint256 lastCancelledProposalId = kevm.freshUInt(8);
        vm.assume(lastCancelledProposalId <= proposalsCount);
        _storeData(address(timelock), 1, 8, 8, lastCancelledProposalId);
        //
        {
            uint160 activationCommittee = uint160(uint256(keccak256("activationCommittee")));
            uint256 protectionEndsAfter = kevm.freshUInt(5);
            vm.assume(protectionEndsAfter < timeUpperBound);
            vm.assume(protectionEndsAfter <= block.timestamp);
            _storeData(address(_timelock), 3, 5, 20, uint256(activationCommittee));
            _storeData(address(_timelock), 3, 25, 5, protectionEndsAfter);
        }
        //
        uint256 emergencyModeEndsAfter = kevm.freshUInt(5);
        vm.assume(emergencyModeEndsAfter < timeUpperBound);
        vm.assume(emergencyModeEndsAfter <= block.timestamp);
        _storeData(address(_timelock), 3, 0, 5, emergencyModeEndsAfter);
    }

    // Set up the storage for a proposal.
    // ?WORD25: submittedAt
    // ?WORD26: scheduledAt
    // ?WORD27: executedAt
    // ?WORD28: numCalls
    function _proposalStorageSetup(EmergencyProtectedTimelock _timelock, uint256 _proposalId) public {
        // slot 1
        {
            uint256 status = kevm.freshUInt(1);
            vm.assume(status <= 4);
            _storeMappingData(address(_timelock), 2, _proposalId, 0, 0, 1, status);
            uint256 executor = uint256(uint160(uint256(keccak256("executor"))));
            _storeMappingData(address(_timelock), 2, _proposalId, 0, 1, 20, executor);
            uint256 submittedAt = kevm.freshUInt(5);
            vm.assume(submittedAt < timeUpperBound);
            vm.assume(submittedAt <= block.timestamp);
            _storeMappingData(address(_timelock), 2, _proposalId, 0, 21, 5, submittedAt);
            uint256 scheduledAt = kevm.freshUInt(5);
            vm.assume(scheduledAt < timeUpperBound);
            vm.assume(scheduledAt <= block.timestamp);
            _storeMappingData(address(_timelock), 2, _proposalId, 0, 26, 5, scheduledAt);
        }
        // TODO: uncomment and adapt this if it becomes necessary
        /*
        // slot 2
        {
            uint40 executedAt = uint40(kevm.freshUInt(5));
            vm.assume(executedAt < timeUpperBound);
            vm.assume(executedAt <= block.timestamp);
            _storeUInt256(address(_timelock), baseSlot + 1, executedAt);
        }
        // slot 3
        {
            uint256 numCalls = kevm.freshUInt(32);
            vm.assume(numCalls < type(uint256).max);
            vm.assume(numCalls > 0);
            _storeUInt256(address(_timelock), baseSlot + 2, numCalls);
        }
        */
    }

    function _storeExecutorCalls(EmergencyProtectedTimelock _timelock, uint256 _proposalId) public {
        uint256 numCalls = _getCallsCount(_timelock, _proposalId);
        uint256 callsSlot = _getCallsSlot(_proposalId);

        for (uint256 j = 0; j < numCalls; j++) {
            uint256 callSlot = callsSlot + j * 2;
            uint256 target = uint256(uint160(uint256(keccak256(abi.encodePacked(j, "target")))));
            _storeData(address(_timelock), callSlot, 0, 20, target);
            uint256 value = kevm.freshUInt(12);
            vm.assume(value != 0);
            _storeData(address(_timelock), callSlot, 20, 12, value);
            // TODO: Fix this if it becomes necessary (careful about how bytes need to be encoded)
            //bytes memory payload = abi.encodePacked(j, "payload");
            //_storeBytes32(address(_timelock), callSlot + 2, keccak256(payload));
        }
    }

    function _proposalIdAssumeBound(uint256 _proposalId) internal view {
        vm.assume(_proposalId > 0);
        vm.assume(_proposalId < _getProposalsCount(timelock));
        uint256 slot2 = uint256(keccak256(abi.encodePacked(uint256(2))));
        vm.assume((_proposalId - 1) <= ((type(uint256).max - 3 - slot2) / 3));
    }

    function _getProposalsSlot(uint256 _proposalId) internal returns (uint256 baseSlot) {
        return uint256(keccak256(abi.encodePacked(_proposalId, uint256(2))));
    }

    function _getCallsSlot(uint256 _proposalId) internal returns (uint256) {
        uint256 proposalsSlot = _getProposalsSlot(_proposalId);
        return uint256(keccak256(abi.encodePacked(proposalsSlot + 1)));
    }

    function _getProtectedTill(EmergencyProtectedTimelock _timelock) internal view returns (uint40) {
        return uint40(_loadUInt256(address(_timelock), 3) >> 160);
    }

    function _getLastCancelledProposalId(EmergencyProtectedTimelock _timelock) internal view returns (uint256) {
        return _loadUInt256(address(_timelock), 1);
    }

    function _getProposalsCount(EmergencyProtectedTimelock _timelock) internal view returns (uint256) {
        return _loadUInt256(address(_timelock), 2);
    }

    function _getEmergencyModeEndsAfter(EmergencyProtectedTimelock _timelock) internal view returns (uint40) {
        return uint40(_loadUInt256(address(_timelock), 4));
    }

    function _getSubmittedAt(EmergencyProtectedTimelock _timelock, uint256 baseSlot) internal view returns (uint40) {
        return uint40(_loadUInt256(address(_timelock), baseSlot) >> 160);
    }

    function _getScheduledAt(EmergencyProtectedTimelock _timelock, uint256 baseSlot) internal view returns (uint40) {
        return uint40(_loadUInt256(address(_timelock), baseSlot) >> 200);
    }

    function _getExecutedAt(EmergencyProtectedTimelock _timelock, uint256 baseSlot) internal view returns (uint40) {
        return uint40(_loadUInt256(address(_timelock), baseSlot + 1));
    }

    function _getCallsCount(
        EmergencyProtectedTimelock _timelock,
        uint256 _proposalId
    ) internal view returns (uint256) {
        return _loadMappingData(address(_timelock), 2, _proposalId, 1, 0, 32);
    }
}
