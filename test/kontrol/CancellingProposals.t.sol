pragma solidity 0.8.26;

import {ExecutableProposals, Status} from "contracts/libraries/ExecutableProposals.sol";
import {TimelockState} from "contracts/libraries/TimelockState.sol";
import {Timestamp, Timestamps} from "contracts/types/Timestamp.sol";

import {DualGovernanceSetUp} from "test/kontrol/DualGovernanceSetUp.sol";

contract CancellingProposalsTest is DualGovernanceSetUp {
    /**
     * cancelAllNonExecutedProposals cannot be called by any address other than
     * the governance address.
     */
    function testOnlyGovernanceCanCancelProposals(address sender) external {
        vm.assume(sender != timelock.getGovernance());

        vm.startPrank(sender);

        bytes4 errorSelector = TimelockState.CallerIsNotGovernance.selector;

        vm.expectRevert(abi.encodeWithSelector(errorSelector, sender));
        timelock.cancelAllNonExecutedProposals();

        vm.stopPrank();
    }

    /**
     * Cancelled proposals cannot be scheduled.
     */
    function testCancelledProposalsCannotBeScheduled(uint256 proposalId) external {
        vm.assume(proposalId < timelock.getProposalsCount());

        _proposalStorageSetup(timelock, proposalId);

        Status proposalStatus = timelock.getProposalDetails(proposalId).status;
        vm.assume(proposalStatus == Status.Cancelled);

        vm.startPrank(timelock.getGovernance());

        bytes4 errorSelector = ExecutableProposals.UnexpectedProposalStatus.selector;

        vm.expectRevert(abi.encodeWithSelector(errorSelector, proposalId, Status.Cancelled));

        timelock.schedule(proposalId);

        vm.stopPrank();
    }

    /**
     * Cancelled proposals cannot be executed.
     */
    function testCancelledProposalsCannotBeExecuted(uint256 proposalId) external {
        vm.assume(proposalId < timelock.getProposalsCount());
        vm.assume(!timelock.isEmergencyModeActive());

        _proposalStorageSetup(timelock, proposalId);

        Status proposalStatus = timelock.getProposalDetails(proposalId).status;
        vm.assume(proposalStatus == Status.Cancelled);

        bytes4 errorSelector = ExecutableProposals.UnexpectedProposalStatus.selector;

        vm.expectRevert(abi.encodeWithSelector(errorSelector, proposalId, Status.Cancelled));

        timelock.execute(proposalId);
    }

    /**
     * Cancelled proposals cannot be emergency-executed.
     */
    function testCancelledProposalsCannotBeEmergencyExecuted(uint256 proposalId) external {
        vm.assume(proposalId < timelock.getProposalsCount());
        vm.assume(timelock.isEmergencyModeActive());

        _proposalStorageSetup(timelock, proposalId);

        Status proposalStatus = timelock.getProposalDetails(proposalId).status;
        vm.assume(proposalStatus == Status.Cancelled);

        vm.startPrank(timelock.getEmergencyExecutionCommittee());

        bytes4 errorSelector = ExecutableProposals.UnexpectedProposalStatus.selector;

        vm.expectRevert(abi.encodeWithSelector(errorSelector, proposalId, Status.Cancelled));

        timelock.emergencyExecute(proposalId);

        vm.stopPrank();
    }
}