// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {Duration} from "../types/Duration.sol";
import {PercentD16} from "../types/PercentD16.sol";
import {Timestamp, Timestamps} from "../types/Timestamp.sol";

import {IEscrow} from "../interfaces/IEscrow.sol";
import {IDualGovernance} from "../interfaces/IDualGovernance.sol";
import {IDualGovernanceConfigProvider} from "../interfaces/IDualGovernanceConfigProvider.sol";

import {DualGovernanceConfig} from "./DualGovernanceConfig.sol";

/// @notice Enum describing the state of the Dual Governance State Machine
/// @param Unset The initial (uninitialized) state of the Dual Governance State Machine. The state machine cannot
///     operate in this state and must be initialized before use.
/// @param Normal The default state where the system is expected to remain most of the time. In this state, proposals
///     can be both submitted and scheduled for execution.
/// @param VetoSignalling Represents active opposition to DAO decisions. In this state, the scheduling of proposals
///     is blocked, but the submission of new proposals is still allowed.
/// @param VetoSignallingDeactivation A sub-state of VetoSignalling, allowing users to observe the deactivation process
///     and react before non-cancelled proposals are scheduled for execution. Both proposal submission and scheduling
///     are prohibited in this state.
/// @param VetoCooldown A state where the DAO can execute non-cancelled proposals but is prohibited from submitting
///     new proposals.
/// @param RageQuit Represents the process where users opting to leave the protocol can withdraw their funds. This state
///     is triggered when the Second Seal Threshold is crossed. During this state, the scheduling of proposals for
///     execution is forbidden, but new proposals can still be submitted.
enum State {
    Unset,
    Normal,
    VetoSignalling,
    VetoSignallingDeactivation,
    VetoCooldown,
    RageQuit
}

/// @title Dual Governance State Machine Library
/// @notice Library containing the core logic for managing the states of the Dual Governance system
library DualGovernanceStateMachine {
    using DualGovernanceStateTransitions for Context;
    using DualGovernanceConfig for DualGovernanceConfig.Context;

    // ---
    // Data types
    // ---

    /// @notice Represents the context of the Dual Governance State Machine.
    /// @param state The last recorded state of the Dual Governance State Machine.
    /// @param enteredAt The timestamp when the current `persisted` `state` was entered.
    /// @param vetoSignallingActivatedAt The timestamp when the VetoSignalling state was last activated.
    /// @param signallingEscrow The address of the Escrow contract used for VetoSignalling.
    /// @param rageQuitRound The number of continuous Rage Quit rounds, starting at 0 and capped at MAX_RAGE_QUIT_ROUND.
    /// @param vetoSignallingReactivationTime The timestamp of the last transition from VetoSignallingDeactivation to VetoSignalling.
    /// @param normalOrVetoCooldownExitedAt The timestamp of the last exit from either the Normal or VetoCooldown state.
    /// @param rageQuitEscrow The address of the Escrow contract used during the most recent (or ongoing) Rage Quit process.
    /// @param configProvider The address of the contract providing the current configuration for the Dual Governance State Machine.
    struct Context {
        /// @dev slot 0: [0..7]
        State state;
        /// @dev slot 0: [8..47]
        Timestamp enteredAt;
        /// @dev slot 0: [48..87]
        Timestamp vetoSignallingActivatedAt;
        /// @dev slot 0: [88..247]
        IEscrow signallingEscrow;
        /// @dev slot 0: [248..255]
        uint8 rageQuitRound;
        /// @dev slot 1: [0..39]
        Timestamp vetoSignallingReactivationTime;
        /// @dev slot 1: [40..79]
        Timestamp normalOrVetoCooldownExitedAt;
        /// @dev slot 1: [80..239]
        IEscrow rageQuitEscrow;
        /// @dev slot 2: [0..159]
        IDualGovernanceConfigProvider configProvider;
    }

    // ---
    // Errors
    // ---

    error AlreadyInitialized();
    error InvalidConfigProvider(IDualGovernanceConfigProvider configProvider);

    // ---
    // Events
    // ---

    event NewSignallingEscrowDeployed(IEscrow indexed escrow);
    event DualGovernanceStateChanged(State from, State to, Context state);
    event ConfigProviderSet(IDualGovernanceConfigProvider newConfigProvider);

    // ---
    // Constants
    // ---

    /// @dev The upper limit for the maximum possible continuous RageQuit rounds. Once this limit is reached,
    ///      the `rageQuitRound` value is capped at 255 until the system returns to the Normal or VetoCooldown state.
    uint256 internal constant MAX_RAGE_QUIT_ROUND = type(uint8).max;

    // ---
    // Main functionality
    // ---

    /// @notice Initializes the Dual Governance State Machine context.
    /// @param self The context of the Dual Governance State Machine to be initialized.
    /// @param configProvider The address of the Dual Governance State Machine configuration provider.
    /// @param escrowMasterCopy The address of the master copy used as the implementation for the minimal proxy deployment
    ///     of a Signalling Escrow instance.
    function initialize(
        Context storage self,
        IDualGovernanceConfigProvider configProvider,
        IEscrow escrowMasterCopy
    ) internal {
        if (self.state != State.Unset) {
            revert AlreadyInitialized();
        }

        self.state = State.Normal;
        self.enteredAt = Timestamps.now();

        _setConfigProvider(self, configProvider);

        DualGovernanceConfig.Context memory config = configProvider.getDualGovernanceConfig();
        _deployNewSignallingEscrow(self, escrowMasterCopy, config.minAssetsLockDuration);

        emit DualGovernanceStateChanged(State.Unset, State.Normal, self);
    }

    /// @notice Executes a state transition for the Dual Governance State Machine, if applicable.
    ///     If no transition is possible from the current `persisted` state, no changes are applied to the context.
    /// @dev If the state transitions to RageQuit, a new instance of the Signalling Escrow is deployed using
    ///     `escrowMasterCopy` as the implementation for the minimal proxy, while the previous Signalling Escrow
    ///     instance is converted into the RageQuit escrow.
    /// @param self The context of the Dual Governance State Machine.
    /// @param escrowMasterCopy The address of the master copy used as the implementation for the minimal proxy
    ///     to deploy a new instance of the Signalling Escrow.
    function activateNextState(Context storage self, IEscrow escrowMasterCopy) internal {
        DualGovernanceConfig.Context memory config = getDualGovernanceConfig(self);
        (State currentState, State newState) = self.getStateTransition(config);

        if (currentState == newState) {
            return;
        }

        self.state = newState;
        self.enteredAt = Timestamps.now();

        if (currentState == State.Normal || currentState == State.VetoCooldown) {
            self.normalOrVetoCooldownExitedAt = Timestamps.now();
        }

        if (newState == State.Normal && self.rageQuitRound != 0) {
            self.rageQuitRound = 0;
        } else if (newState == State.VetoSignalling) {
            if (currentState == State.VetoSignallingDeactivation) {
                self.vetoSignallingReactivationTime = Timestamps.now();
            } else {
                self.vetoSignallingActivatedAt = Timestamps.now();
            }
        } else if (newState == State.RageQuit) {
            IEscrow signallingEscrow = self.signallingEscrow;

            uint256 currentRageQuitRound = self.rageQuitRound;

            /// @dev Limits the maximum value of the rage quit round to prevent failures due to arithmetic overflow
            ///     if the number of continuous rage quits reaches MAX_RAGE_QUIT_ROUND.
            uint256 newRageQuitRound = Math.min(currentRageQuitRound + 1, MAX_RAGE_QUIT_ROUND);
            self.rageQuitRound = uint8(newRageQuitRound);

            signallingEscrow.startRageQuit(
                config.rageQuitExtensionPeriodDuration, config.calcRageQuitWithdrawalsDelay(newRageQuitRound)
            );
            self.rageQuitEscrow = signallingEscrow;
            _deployNewSignallingEscrow(self, escrowMasterCopy, config.minAssetsLockDuration);
        }

        emit DualGovernanceStateChanged(currentState, newState, self);
    }

    /// @notice Updates the address of the configuration provider for the Dual Governance State Machine.
    /// @param self The context of the Dual Governance State Machine.
    /// @param newConfigProvider The address of the new configuration provider.
    function setConfigProvider(Context storage self, IDualGovernanceConfigProvider newConfigProvider) internal {
        _setConfigProvider(self, newConfigProvider);

        /// @dev minAssetsLockDuration is stored as a storage variable in the Signalling Escrow instance.
        ///      To synchronize the new value with the current Signalling Escrow, it must be manually updated.
        self.signallingEscrow.setMinAssetsLockDuration(
            newConfigProvider.getDualGovernanceConfig().minAssetsLockDuration
        );
    }

    // ---
    // Getters
    // ---

    /// @notice Returns detailed information about the state of the Dual Governance State Machine.
    /// @param self The context of the Dual Governance State Machine.
    /// @return stateDetails A struct containing detailed information about the state of
    ///     the Dual Governance State Machine.
    function getStateDetails(Context storage self)
        internal
        view
        returns (IDualGovernance.StateDetails memory stateDetails)
    {
        DualGovernanceConfig.Context memory config = getDualGovernanceConfig(self);
        (stateDetails.persistedState, stateDetails.effectiveState) = self.getStateTransition(config);

        stateDetails.persistedStateEnteredAt = self.enteredAt;
        stateDetails.vetoSignallingActivatedAt = self.vetoSignallingActivatedAt;
        stateDetails.vetoSignallingReactivationTime = self.vetoSignallingReactivationTime;
        stateDetails.normalOrVetoCooldownExitedAt = self.normalOrVetoCooldownExitedAt;
        stateDetails.rageQuitRound = self.rageQuitRound;
        stateDetails.vetoSignallingDuration =
            config.calcVetoSignallingDuration(self.signallingEscrow.getRageQuitSupport());
    }

    /// @notice Returns the most recently persisted state of the Dual Governance State Machine.
    /// @param self The context of the Dual Governance State Machine.
    /// @return persistedState The state of the Dual Governance State Machine as last stored.
    function getPersistedState(Context storage self) internal view returns (State persistedState) {
        persistedState = self.state;
    }

    /// @notice Returns the effective state of the Dual Governance State Machine.
    /// @dev The effective state refers to the state the Dual Governance State Machine would transition to
    ///     upon calling `activateNextState()`.
    /// @param self The context of the Dual Governance State Machine.
    /// @return effectiveState The state that will become active after the next state transition.
    ///     If the `activateNextState` call does not trigger a state transition, `effectiveState`
    ///     will be the same as `persistedState`.
    function getEffectiveState(Context storage self) internal view returns (State effectiveState) {
        ( /* persistedState */ , effectiveState) = self.getStateTransition(getDualGovernanceConfig(self));
    }

    /// @notice Returns whether the submission of proposals is allowed based on the `persisted` or `effective` state,
    ///     depending on the `useEffectiveState` value.
    /// @param self The context of the Dual Governance State Machine.
    /// @param useEffectiveState If `true`, the check is performed against the `effective` state, which represents the state
    ///     the Dual Governance State Machine will enter after the next `activateNextState` call. If `false`, the check is
    ///     performed against the `persisted` state, which is the currently stored state of the system.
    /// @return A boolean indicating whether the submission of proposals is allowed in the selected state.
    function canSubmitProposal(Context storage self, bool useEffectiveState) internal view returns (bool) {
        State state = useEffectiveState ? getEffectiveState(self) : getPersistedState(self);
        return state != State.VetoSignallingDeactivation && state != State.VetoCooldown;
    }

    /// @notice Determines whether scheduling a proposal for execution is allowed, based on either the `persisted`
    ///     or `effective` state, depending on the `useEffectiveState` flag.
    /// @param self The context of the Dual Governance State Machine.
    /// @param useEffectiveState If `true`, the check is performed against the `effective` state, which represents the state
    ///     the Dual Governance State Machine will enter after the next `activateNextState` call. If `false`, the check is
    ///     performed against the `persisted` state, which is the currently stored state of the system.
    /// @param proposalSubmittedAt The timestamp indicating when the proposal to be scheduled was originally submitted.
    /// @return A boolean indicating whether scheduling the proposal is allowed in the chosen state.
    function canScheduleProposal(
        Context storage self,
        bool useEffectiveState,
        Timestamp proposalSubmittedAt
    ) internal view returns (bool) {
        State state = useEffectiveState ? getEffectiveState(self) : getPersistedState(self);
        if (state == State.Normal) return true;
        if (state == State.VetoCooldown) return proposalSubmittedAt <= self.vetoSignallingActivatedAt;
        return false;
    }

    /// @notice Returns whether the cancelling of the proposals is allowed based on the `persisted` or `effective`
    ///     state, depending on the `useEffectiveState` value.
    /// @param self The context of the Dual Governance State Machine.
    /// @param useEffectiveState If `true`, the check is performed against the `effective` state, which represents the state
    ///     the Dual Governance State Machine will enter after the next `activateNextState` call. If `false`, the check is
    ///     performed against the `persisted` state, which is the currently stored state of the system.
    /// @return A boolean indicating whether the cancelling of proposals is allowed in the selected state.
    function canCancelAllPendingProposals(Context storage self, bool useEffectiveState) internal view returns (bool) {
        State state = useEffectiveState ? getEffectiveState(self) : getPersistedState(self);
        return state == State.VetoSignalling || state == State.VetoSignallingDeactivation;
    }

    /// @notice Returns the configuration of the Dual Governance State Machine as provided by
    ///     the Dual Governance Config Provider.
    /// @param self The context of the Dual Governance State Machine.
    /// @return The current configuration of the Dual Governance State
    function getDualGovernanceConfig(Context storage self)
        internal
        view
        returns (DualGovernanceConfig.Context memory)
    {
        return self.configProvider.getDualGovernanceConfig();
    }

    // ---
    // Private Methods
    // ---

    function _setConfigProvider(Context storage self, IDualGovernanceConfigProvider newConfigProvider) private {
        if (address(newConfigProvider) == address(0) || newConfigProvider == self.configProvider) {
            revert InvalidConfigProvider(newConfigProvider);
        }

        newConfigProvider.getDualGovernanceConfig().validate();

        self.configProvider = newConfigProvider;
        emit ConfigProviderSet(newConfigProvider);
    }

    function _deployNewSignallingEscrow(
        Context storage self,
        IEscrow escrowMasterCopy,
        Duration minAssetsLockDuration
    ) private {
        IEscrow newSignallingEscrow = IEscrow(Clones.clone(address(escrowMasterCopy)));
        newSignallingEscrow.initialize(minAssetsLockDuration);
        self.signallingEscrow = newSignallingEscrow;
        emit NewSignallingEscrowDeployed(newSignallingEscrow);
    }
}

/// @title Dual Governance State Transitions Library
/// @notice Library containing the transitions logic for the Dual Governance system
library DualGovernanceStateTransitions {
    using DualGovernanceConfig for DualGovernanceConfig.Context;

    /// @notice Returns the allowed state transition for the Dual Governance State Machine.
    ///     If no state transition is possible, `currentState` will be equal to `nextState`.
    /// @param self The context of the Dual Governance State Machine.
    /// @param config The configuration of the Dual Governance State Machine to use for determining
    ///     state transitions.
    /// @return currentState The current state of the Dual Governance State Machine.
    /// @return nextState The next state of the Dual Governance State Machine if a transition
    ///     is possible, otherwise it will be the same as `currentState`.
    function getStateTransition(
        DualGovernanceStateMachine.Context storage self,
        DualGovernanceConfig.Context memory config
    ) internal view returns (State currentState, State nextState) {
        currentState = self.state;
        if (currentState == State.Normal) {
            nextState = _fromNormalState(self, config);
        } else if (currentState == State.VetoSignalling) {
            nextState = _fromVetoSignallingState(self, config);
        } else if (currentState == State.VetoSignallingDeactivation) {
            nextState = _fromVetoSignallingDeactivationState(self, config);
        } else if (currentState == State.VetoCooldown) {
            nextState = _fromVetoCooldownState(self, config);
        } else if (currentState == State.RageQuit) {
            nextState = _fromRageQuitState(self, config);
        } else {
            assert(false);
        }
    }

    // ---
    // Private Methods
    // ---

    function _fromNormalState(
        DualGovernanceStateMachine.Context storage self,
        DualGovernanceConfig.Context memory config
    ) private view returns (State) {
        return config.isFirstSealRageQuitSupportCrossed(self.signallingEscrow.getRageQuitSupport())
            ? State.VetoSignalling
            : State.Normal;
    }

    function _fromVetoSignallingState(
        DualGovernanceStateMachine.Context storage self,
        DualGovernanceConfig.Context memory config
    ) private view returns (State) {
        PercentD16 rageQuitSupport = self.signallingEscrow.getRageQuitSupport();

        if (!config.isVetoSignallingDurationPassed(self.vetoSignallingActivatedAt, rageQuitSupport)) {
            return State.VetoSignalling;
        }

        if (config.isSecondSealRageQuitSupportCrossed(rageQuitSupport)) {
            return State.RageQuit;
        }

        return config.isVetoSignallingReactivationDurationPassed(
            Timestamps.max(self.vetoSignallingReactivationTime, self.vetoSignallingActivatedAt)
        ) ? State.VetoSignallingDeactivation : State.VetoSignalling;
    }

    function _fromVetoSignallingDeactivationState(
        DualGovernanceStateMachine.Context storage self,
        DualGovernanceConfig.Context memory config
    ) private view returns (State) {
        PercentD16 rageQuitSupport = self.signallingEscrow.getRageQuitSupport();

        if (!config.isVetoSignallingDurationPassed(self.vetoSignallingActivatedAt, rageQuitSupport)) {
            return State.VetoSignalling;
        }

        if (config.isSecondSealRageQuitSupportCrossed(rageQuitSupport)) {
            return State.RageQuit;
        }

        if (config.isVetoSignallingDeactivationMaxDurationPassed(self.enteredAt)) {
            return State.VetoCooldown;
        }

        return State.VetoSignallingDeactivation;
    }

    function _fromVetoCooldownState(
        DualGovernanceStateMachine.Context storage self,
        DualGovernanceConfig.Context memory config
    ) private view returns (State) {
        if (!config.isVetoCooldownDurationPassed(self.enteredAt)) {
            return State.VetoCooldown;
        }
        return config.isFirstSealRageQuitSupportCrossed(self.signallingEscrow.getRageQuitSupport())
            ? State.VetoSignalling
            : State.Normal;
    }

    function _fromRageQuitState(
        DualGovernanceStateMachine.Context storage self,
        DualGovernanceConfig.Context memory config
    ) private view returns (State) {
        if (!self.rageQuitEscrow.isRageQuitFinalized()) {
            return State.RageQuit;
        }
        return config.isFirstSealRageQuitSupportCrossed(self.signallingEscrow.getRageQuitSupport())
            ? State.VetoSignalling
            : State.VetoCooldown;
    }
}
