pragma solidity 0.8.26;

library DualGovernanceStorageConstants {
    uint256 public constant STORAGE_PROPOSERS_PROPOSERS_SLOT = 0;
    uint256 public constant STORAGE_PROPOSERS_PROPOSERS_OFFSET = 0;
    uint256 public constant STORAGE_PROPOSERS_PROPOSERS_SIZE = 32;
    uint256 public constant STORAGE_PROPOSERS_EXECUTORS_SLOT = 1;
    uint256 public constant STORAGE_PROPOSERS_EXECUTORS_OFFSET = 0;
    uint256 public constant STORAGE_PROPOSERS_EXECUTORS_SIZE = 32;
    uint256 public constant STORAGE_PROPOSERS_EXECUTORREFSCOUNTS_SLOT = 2;
    uint256 public constant STORAGE_PROPOSERS_EXECUTORREFSCOUNTS_OFFSET = 0;
    uint256 public constant STORAGE_PROPOSERS_EXECUTORREFSCOUNTS_SIZE = 32;
    uint256 public constant STORAGE_TIEBREAKER_TIEBREAKERCOMMITTEE_SLOT = 3;
    uint256 public constant STORAGE_TIEBREAKER_TIEBREAKERCOMMITTEE_OFFSET = 0;
    uint256 public constant STORAGE_TIEBREAKER_TIEBREAKERCOMMITTEE_SIZE = 20;
    uint256 public constant STORAGE_TIEBREAKER_TIEBREAKERACTIVATIONTIMEOUT_SLOT = 3;
    uint256 public constant STORAGE_TIEBREAKER_TIEBREAKERACTIVATIONTIMEOUT_OFFSET = 20;
    uint256 public constant STORAGE_TIEBREAKER_TIEBREAKERACTIVATIONTIMEOUT_SIZE = 4;
    uint256 public constant STORAGE_TIEBREAKER_SEALABLEWITHDRAWALBLOCKERS_INNER_VALUES_SLOT = 4;
    uint256 public constant STORAGE_TIEBREAKER_SEALABLEWITHDRAWALBLOCKERS_INNER_VALUES_OFFSET = 0;
    uint256 public constant STORAGE_TIEBREAKER_SEALABLEWITHDRAWALBLOCKERS_INNER_VALUES_SIZE = 32;
    uint256 public constant STORAGE_TIEBREAKER_SEALABLEWITHDRAWALBLOCKERS_INNER_POSITIONS_SLOT = 5;
    uint256 public constant STORAGE_TIEBREAKER_SEALABLEWITHDRAWALBLOCKERS_INNER_POSITIONS_OFFSET = 0;
    uint256 public constant STORAGE_TIEBREAKER_SEALABLEWITHDRAWALBLOCKERS_INNER_POSITIONS_SIZE = 32;
    uint256 public constant STORAGE_STATEMACHINE_STATE_SLOT = 6;
    uint256 public constant STORAGE_STATEMACHINE_STATE_OFFSET = 0;
    uint256 public constant STORAGE_STATEMACHINE_STATE_SIZE = 1;
    uint256 public constant STORAGE_STATEMACHINE_ENTEREDAT_SLOT = 6;
    uint256 public constant STORAGE_STATEMACHINE_ENTEREDAT_OFFSET = 1;
    uint256 public constant STORAGE_STATEMACHINE_ENTEREDAT_SIZE = 5;
    uint256 public constant STORAGE_STATEMACHINE_VETOSIGNALLINGACTIVATEDAT_SLOT = 6;
    uint256 public constant STORAGE_STATEMACHINE_VETOSIGNALLINGACTIVATEDAT_OFFSET = 6;
    uint256 public constant STORAGE_STATEMACHINE_VETOSIGNALLINGACTIVATEDAT_SIZE = 5;
    uint256 public constant STORAGE_STATEMACHINE_SIGNALLINGESCROW_SLOT = 6;
    uint256 public constant STORAGE_STATEMACHINE_SIGNALLINGESCROW_OFFSET = 11;
    uint256 public constant STORAGE_STATEMACHINE_SIGNALLINGESCROW_SIZE = 20;
    uint256 public constant STORAGE_STATEMACHINE_RAGEQUITROUND_SLOT = 6;
    uint256 public constant STORAGE_STATEMACHINE_RAGEQUITROUND_OFFSET = 31;
    uint256 public constant STORAGE_STATEMACHINE_RAGEQUITROUND_SIZE = 1;
    uint256 public constant STORAGE_STATEMACHINE_VETOSIGNALLINGREACTIVATIONTIME_SLOT = 7;
    uint256 public constant STORAGE_STATEMACHINE_VETOSIGNALLINGREACTIVATIONTIME_OFFSET = 0;
    uint256 public constant STORAGE_STATEMACHINE_VETOSIGNALLINGREACTIVATIONTIME_SIZE = 5;
    uint256 public constant STORAGE_STATEMACHINE_NORMALORVETOCOOLDOWNEXITEDAT_SLOT = 7;
    uint256 public constant STORAGE_STATEMACHINE_NORMALORVETOCOOLDOWNEXITEDAT_OFFSET = 5;
    uint256 public constant STORAGE_STATEMACHINE_NORMALORVETOCOOLDOWNEXITEDAT_SIZE = 5;
    uint256 public constant STORAGE_STATEMACHINE_RAGEQUITESCROW_SLOT = 7;
    uint256 public constant STORAGE_STATEMACHINE_RAGEQUITESCROW_OFFSET = 10;
    uint256 public constant STORAGE_STATEMACHINE_RAGEQUITESCROW_SIZE = 20;
    uint256 public constant STORAGE_STATEMACHINE_CONFIGPROVIDER_SLOT = 8;
    uint256 public constant STORAGE_STATEMACHINE_CONFIGPROVIDER_OFFSET = 0;
    uint256 public constant STORAGE_STATEMACHINE_CONFIGPROVIDER_SIZE = 20;
    uint256 public constant STORAGE_RESEALER_RESEALMANAGER_SLOT = 9;
    uint256 public constant STORAGE_RESEALER_RESEALMANAGER_OFFSET = 0;
    uint256 public constant STORAGE_RESEALER_RESEALMANAGER_SIZE = 20;
    uint256 public constant STORAGE_RESEALER_RESEALCOMMITTEE_SLOT = 10;
    uint256 public constant STORAGE_RESEALER_RESEALCOMMITTEE_OFFSET = 0;
    uint256 public constant STORAGE_RESEALER_RESEALCOMMITTEE_SIZE = 20;
    uint256 public constant STORAGE_PROPOSALSCANCELLER_SLOT = 11;
    uint256 public constant STORAGE_PROPOSALSCANCELLER_OFFSET = 0;
    uint256 public constant STORAGE_PROPOSALSCANCELLER_SIZE = 20;
    uint256 public constant STRUCT_ENUMERABLESET_ADDRESSSET_INNER_VALUES_SLOT = 0;
    uint256 public constant STRUCT_ENUMERABLESET_ADDRESSSET_INNER_VALUES_OFFSET = 0;
    uint256 public constant STRUCT_ENUMERABLESET_ADDRESSSET_INNER_VALUES_SIZE = 32;
    uint256 public constant STRUCT_ENUMERABLESET_ADDRESSSET_INNER_POSITIONS_SLOT = 1;
    uint256 public constant STRUCT_ENUMERABLESET_ADDRESSSET_INNER_POSITIONS_OFFSET = 0;
    uint256 public constant STRUCT_ENUMERABLESET_ADDRESSSET_INNER_POSITIONS_SIZE = 32;
    uint256 public constant STRUCT_PROPOSERS_CONTEXT_PROPOSERS_SLOT = 0;
    uint256 public constant STRUCT_PROPOSERS_CONTEXT_PROPOSERS_OFFSET = 0;
    uint256 public constant STRUCT_PROPOSERS_CONTEXT_PROPOSERS_SIZE = 32;
    uint256 public constant STRUCT_PROPOSERS_CONTEXT_EXECUTORS_SLOT = 1;
    uint256 public constant STRUCT_PROPOSERS_CONTEXT_EXECUTORS_OFFSET = 0;
    uint256 public constant STRUCT_PROPOSERS_CONTEXT_EXECUTORS_SIZE = 32;
    uint256 public constant STRUCT_PROPOSERS_CONTEXT_EXECUTORREFSCOUNTS_SLOT = 2;
    uint256 public constant STRUCT_PROPOSERS_CONTEXT_EXECUTORREFSCOUNTS_OFFSET = 0;
    uint256 public constant STRUCT_PROPOSERS_CONTEXT_EXECUTORREFSCOUNTS_SIZE = 32;
    uint256 public constant STRUCT_RESEALER_CONTEXT_RESEALMANAGER_SLOT = 0;
    uint256 public constant STRUCT_RESEALER_CONTEXT_RESEALMANAGER_OFFSET = 0;
    uint256 public constant STRUCT_RESEALER_CONTEXT_RESEALMANAGER_SIZE = 20;
    uint256 public constant STRUCT_RESEALER_CONTEXT_RESEALCOMMITTEE_SLOT = 1;
    uint256 public constant STRUCT_RESEALER_CONTEXT_RESEALCOMMITTEE_OFFSET = 0;
    uint256 public constant STRUCT_RESEALER_CONTEXT_RESEALCOMMITTEE_SIZE = 20;
    uint256 public constant STRUCT_TIEBREAKER_CONTEXT_TIEBREAKERCOMMITTEE_SLOT = 0;
    uint256 public constant STRUCT_TIEBREAKER_CONTEXT_TIEBREAKERCOMMITTEE_OFFSET = 0;
    uint256 public constant STRUCT_TIEBREAKER_CONTEXT_TIEBREAKERCOMMITTEE_SIZE = 20;
    uint256 public constant STRUCT_TIEBREAKER_CONTEXT_TIEBREAKERACTIVATIONTIMEOUT_SLOT = 0;
    uint256 public constant STRUCT_TIEBREAKER_CONTEXT_TIEBREAKERACTIVATIONTIMEOUT_OFFSET = 20;
    uint256 public constant STRUCT_TIEBREAKER_CONTEXT_TIEBREAKERACTIVATIONTIMEOUT_SIZE = 4;
    uint256 public constant STRUCT_TIEBREAKER_CONTEXT_SEALABLEWITHDRAWALBLOCKERS_INNER_VALUES_SLOT = 1;
    uint256 public constant STRUCT_TIEBREAKER_CONTEXT_SEALABLEWITHDRAWALBLOCKERS_INNER_VALUES_OFFSET = 0;
    uint256 public constant STRUCT_TIEBREAKER_CONTEXT_SEALABLEWITHDRAWALBLOCKERS_INNER_VALUES_SIZE = 32;
    uint256 public constant STRUCT_TIEBREAKER_CONTEXT_SEALABLEWITHDRAWALBLOCKERS_INNER_POSITIONS_SLOT = 2;
    uint256 public constant STRUCT_TIEBREAKER_CONTEXT_SEALABLEWITHDRAWALBLOCKERS_INNER_POSITIONS_OFFSET = 0;
    uint256 public constant STRUCT_TIEBREAKER_CONTEXT_SEALABLEWITHDRAWALBLOCKERS_INNER_POSITIONS_SIZE = 32;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_STATE_SLOT = 0;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_STATE_OFFSET = 0;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_STATE_SIZE = 1;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_ENTEREDAT_SLOT = 0;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_ENTEREDAT_OFFSET = 1;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_ENTEREDAT_SIZE = 5;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_VETOSIGNALLINGACTIVATEDAT_SLOT = 0;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_VETOSIGNALLINGACTIVATEDAT_OFFSET = 6;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_VETOSIGNALLINGACTIVATEDAT_SIZE = 5;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_SIGNALLINGESCROW_SLOT = 0;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_SIGNALLINGESCROW_OFFSET = 11;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_SIGNALLINGESCROW_SIZE = 20;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_RAGEQUITROUND_SLOT = 0;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_RAGEQUITROUND_OFFSET = 31;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_RAGEQUITROUND_SIZE = 1;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_VETOSIGNALLINGREACTIVATIONTIME_SLOT = 1;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_VETOSIGNALLINGREACTIVATIONTIME_OFFSET = 0;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_VETOSIGNALLINGREACTIVATIONTIME_SIZE = 5;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_NORMALORVETOCOOLDOWNEXITEDAT_SLOT = 1;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_NORMALORVETOCOOLDOWNEXITEDAT_OFFSET = 5;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_NORMALORVETOCOOLDOWNEXITEDAT_SIZE = 5;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_RAGEQUITESCROW_SLOT = 1;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_RAGEQUITESCROW_OFFSET = 10;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_RAGEQUITESCROW_SIZE = 20;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_CONFIGPROVIDER_SLOT = 2;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_CONFIGPROVIDER_OFFSET = 0;
    uint256 public constant STRUCT_DUALGOVERNANCESTATEMACHINE_CONTEXT_CONFIGPROVIDER_SIZE = 20;
    uint256 public constant STRUCT_PROPOSERS_EXECUTORDATA_PROPOSERINDEX_SLOT = 0;
    uint256 public constant STRUCT_PROPOSERS_EXECUTORDATA_PROPOSERINDEX_OFFSET = 0;
    uint256 public constant STRUCT_PROPOSERS_EXECUTORDATA_PROPOSERINDEX_SIZE = 4;
    uint256 public constant STRUCT_PROPOSERS_EXECUTORDATA_EXECUTOR_SLOT = 0;
    uint256 public constant STRUCT_PROPOSERS_EXECUTORDATA_EXECUTOR_OFFSET = 4;
    uint256 public constant STRUCT_PROPOSERS_EXECUTORDATA_EXECUTOR_SIZE = 20;
    uint256 public constant STRUCT_ENUMERABLESET_SET_VALUES_SLOT = 0;
    uint256 public constant STRUCT_ENUMERABLESET_SET_VALUES_OFFSET = 0;
    uint256 public constant STRUCT_ENUMERABLESET_SET_VALUES_SIZE = 32;
    uint256 public constant STRUCT_ENUMERABLESET_SET_POSITIONS_SLOT = 1;
    uint256 public constant STRUCT_ENUMERABLESET_SET_POSITIONS_OFFSET = 0;
    uint256 public constant STRUCT_ENUMERABLESET_SET_POSITIONS_SIZE = 32;
}