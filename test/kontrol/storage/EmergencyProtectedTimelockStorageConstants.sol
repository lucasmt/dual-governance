pragma solidity 0.8.26;

library EmergencyProtectedTimelockStorageConstants {
    uint256 public constant STORAGE_TIMELOCKSTATE_GOVERNANCE_SLOT = 0;
    uint256 public constant STORAGE_TIMELOCKSTATE_GOVERNANCE_OFFSET = 0;
    uint256 public constant STORAGE_TIMELOCKSTATE_GOVERNANCE_SIZE = 20;
    uint256 public constant STORAGE_TIMELOCKSTATE_AFTERSUBMITDELAY_SLOT = 0;
    uint256 public constant STORAGE_TIMELOCKSTATE_AFTERSUBMITDELAY_OFFSET = 20;
    uint256 public constant STORAGE_TIMELOCKSTATE_AFTERSUBMITDELAY_SIZE = 4;
    uint256 public constant STORAGE_TIMELOCKSTATE_AFTERSCHEDULEDELAY_SLOT = 0;
    uint256 public constant STORAGE_TIMELOCKSTATE_AFTERSCHEDULEDELAY_OFFSET = 24;
    uint256 public constant STORAGE_TIMELOCKSTATE_AFTERSCHEDULEDELAY_SIZE = 4;
    uint256 public constant STORAGE_TIMELOCKSTATE_ADMINEXECUTOR_SLOT = 1;
    uint256 public constant STORAGE_TIMELOCKSTATE_ADMINEXECUTOR_OFFSET = 0;
    uint256 public constant STORAGE_TIMELOCKSTATE_ADMINEXECUTOR_SIZE = 20;
    uint256 public constant STORAGE_PROPOSALS_PROPOSALSCOUNT_SLOT = 2;
    uint256 public constant STORAGE_PROPOSALS_PROPOSALSCOUNT_OFFSET = 0;
    uint256 public constant STORAGE_PROPOSALS_PROPOSALSCOUNT_SIZE = 8;
    uint256 public constant STORAGE_PROPOSALS_LASTCANCELLEDPROPOSALID_SLOT = 2;
    uint256 public constant STORAGE_PROPOSALS_LASTCANCELLEDPROPOSALID_OFFSET = 8;
    uint256 public constant STORAGE_PROPOSALS_LASTCANCELLEDPROPOSALID_SIZE = 8;
    uint256 public constant STORAGE_PROPOSALS_PROPOSALS_SLOT = 3;
    uint256 public constant STORAGE_PROPOSALS_PROPOSALS_OFFSET = 0;
    uint256 public constant STORAGE_PROPOSALS_PROPOSALS_SIZE = 32;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYMODEENDSAFTER_SLOT = 4;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYMODEENDSAFTER_OFFSET = 0;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYMODEENDSAFTER_SIZE = 5;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYACTIVATIONCOMMITTEE_SLOT = 4;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYACTIVATIONCOMMITTEE_OFFSET = 5;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYACTIVATIONCOMMITTEE_SIZE = 20;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYPROTECTIONENDSAFTER_SLOT = 4;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYPROTECTIONENDSAFTER_OFFSET = 25;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYPROTECTIONENDSAFTER_SIZE = 5;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYEXECUTIONCOMMITTEE_SLOT = 5;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYEXECUTIONCOMMITTEE_OFFSET = 0;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYEXECUTIONCOMMITTEE_SIZE = 20;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYMODEDURATION_SLOT = 5;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYMODEDURATION_OFFSET = 20;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYMODEDURATION_SIZE = 4;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYGOVERNANCE_SLOT = 6;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYGOVERNANCE_OFFSET = 0;
    uint256 public constant STORAGE_EMERGENCYPROTECTION_EMERGENCYGOVERNANCE_SIZE = 20;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_CONTEXT_PROPOSALSCOUNT_SLOT = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_CONTEXT_PROPOSALSCOUNT_OFFSET = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_CONTEXT_PROPOSALSCOUNT_SIZE = 8;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_CONTEXT_LASTCANCELLEDPROPOSALID_SLOT = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_CONTEXT_LASTCANCELLEDPROPOSALID_OFFSET = 8;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_CONTEXT_LASTCANCELLEDPROPOSALID_SIZE = 8;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_CONTEXT_PROPOSALS_SLOT = 1;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_CONTEXT_PROPOSALS_OFFSET = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_CONTEXT_PROPOSALS_SIZE = 32;
    uint256 public constant STRUCT_TIMELOCKSTATE_CONTEXT_GOVERNANCE_SLOT = 0;
    uint256 public constant STRUCT_TIMELOCKSTATE_CONTEXT_GOVERNANCE_OFFSET = 0;
    uint256 public constant STRUCT_TIMELOCKSTATE_CONTEXT_GOVERNANCE_SIZE = 20;
    uint256 public constant STRUCT_TIMELOCKSTATE_CONTEXT_AFTERSUBMITDELAY_SLOT = 0;
    uint256 public constant STRUCT_TIMELOCKSTATE_CONTEXT_AFTERSUBMITDELAY_OFFSET = 20;
    uint256 public constant STRUCT_TIMELOCKSTATE_CONTEXT_AFTERSUBMITDELAY_SIZE = 4;
    uint256 public constant STRUCT_TIMELOCKSTATE_CONTEXT_AFTERSCHEDULEDELAY_SLOT = 0;
    uint256 public constant STRUCT_TIMELOCKSTATE_CONTEXT_AFTERSCHEDULEDELAY_OFFSET = 24;
    uint256 public constant STRUCT_TIMELOCKSTATE_CONTEXT_AFTERSCHEDULEDELAY_SIZE = 4;
    uint256 public constant STRUCT_TIMELOCKSTATE_CONTEXT_ADMINEXECUTOR_SLOT = 1;
    uint256 public constant STRUCT_TIMELOCKSTATE_CONTEXT_ADMINEXECUTOR_OFFSET = 0;
    uint256 public constant STRUCT_TIMELOCKSTATE_CONTEXT_ADMINEXECUTOR_SIZE = 20;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYMODEENDSAFTER_SLOT = 0;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYMODEENDSAFTER_OFFSET = 0;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYMODEENDSAFTER_SIZE = 5;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYACTIVATIONCOMMITTEE_SLOT = 0;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYACTIVATIONCOMMITTEE_OFFSET = 5;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYACTIVATIONCOMMITTEE_SIZE = 20;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYPROTECTIONENDSAFTER_SLOT = 0;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYPROTECTIONENDSAFTER_OFFSET = 25;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYPROTECTIONENDSAFTER_SIZE = 5;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYEXECUTIONCOMMITTEE_SLOT = 1;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYEXECUTIONCOMMITTEE_OFFSET = 0;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYEXECUTIONCOMMITTEE_SIZE = 20;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYMODEDURATION_SLOT = 1;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYMODEDURATION_OFFSET = 20;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYMODEDURATION_SIZE = 4;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYGOVERNANCE_SLOT = 2;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYGOVERNANCE_OFFSET = 0;
    uint256 public constant STRUCT_EMERGENCYPROTECTION_CONTEXT_EMERGENCYGOVERNANCE_SIZE = 20;
    uint256 public constant STRUCT_EXTERNALCALL_TARGET_SLOT = 0;
    uint256 public constant STRUCT_EXTERNALCALL_TARGET_OFFSET = 0;
    uint256 public constant STRUCT_EXTERNALCALL_TARGET_SIZE = 20;
    uint256 public constant STRUCT_EXTERNALCALL_VALUE_SLOT = 0;
    uint256 public constant STRUCT_EXTERNALCALL_VALUE_OFFSET = 20;
    uint256 public constant STRUCT_EXTERNALCALL_VALUE_SIZE = 12;
    uint256 public constant STRUCT_EXTERNALCALL_PAYLOAD_SLOT = 1;
    uint256 public constant STRUCT_EXTERNALCALL_PAYLOAD_OFFSET = 0;
    uint256 public constant STRUCT_EXTERNALCALL_PAYLOAD_SIZE = 32;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_DATA_STATUS_SLOT = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_DATA_STATUS_OFFSET = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_DATA_STATUS_SIZE = 1;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_DATA_EXECUTOR_SLOT = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_DATA_EXECUTOR_OFFSET = 1;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_DATA_EXECUTOR_SIZE = 20;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_DATA_SUBMITTEDAT_SLOT = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_DATA_SUBMITTEDAT_OFFSET = 21;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_DATA_SUBMITTEDAT_SIZE = 5;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_DATA_SCHEDULEDAT_SLOT = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_DATA_SCHEDULEDAT_OFFSET = 26;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_DATA_SCHEDULEDAT_SIZE = 5;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_CALLS_SLOT = 1;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_CALLS_OFFSET = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSAL_CALLS_SIZE = 32;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSALDATA_STATUS_SLOT = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSALDATA_STATUS_OFFSET = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSALDATA_STATUS_SIZE = 1;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSALDATA_EXECUTOR_SLOT = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSALDATA_EXECUTOR_OFFSET = 1;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSALDATA_EXECUTOR_SIZE = 20;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSALDATA_SUBMITTEDAT_SLOT = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSALDATA_SUBMITTEDAT_OFFSET = 21;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSALDATA_SUBMITTEDAT_SIZE = 5;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSALDATA_SCHEDULEDAT_SLOT = 0;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSALDATA_SCHEDULEDAT_OFFSET = 26;
    uint256 public constant STRUCT_EXECUTABLEPROPOSALS_PROPOSALDATA_SCHEDULEDAT_SIZE = 5;
}
