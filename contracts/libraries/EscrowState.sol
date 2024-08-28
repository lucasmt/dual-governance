// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Duration} from "../types/Duration.sol";
import {Timestamp, Timestamps} from "../types/Timestamp.sol";

/// @notice The state of Escrow representing the current set of actions allowed to be called
///         on the Escrow instance.
/// @param NotInitialized The default (uninitialized) state of the Escrow contract. Only the master
///        copy of the Escrow contract is expected to be in this state.
/// @param SignallingEscrow In this state, the Escrow contract functions as an on-chain oracle for measuring stakers' disagreement
///        with DAO decisions. Users are allowed to lock and unlock funds in the Escrow contract in this state.
/// @param RageQuitEscrow The final state of the Escrow contract. In this state, the Escrow instance acts as an accumulator
///        for withdrawn funds locked during the VetoSignalling phase.
enum State {
    NotInitialized,
    SignallingEscrow,
    RageQuitEscrow
}

/// @title EscrowState
/// @notice Represents the logic to manipulate the state of the Escrow
library EscrowState {
    // ---
    // Errors
    // ---

    error ClaimingIsFinished();
    error UnexpectedState(State value);
    error RageQuitExtraTimelockNotStarted();
    error WithdrawalsTimelockNotPassed();
    error InvalidMinAssetsLockDuration(Duration newMinAssetsLockDuration);

    // ---
    // Events
    // ---

    event RageQuitTimelockStarted(Timestamp startedAt);
    event EscrowStateChanged(State from, State to);
    event RageQuitStarted(Duration rageQuitExtensionDelay, Duration rageQuitWithdrawalsTimelock);
    event MinAssetsLockDurationSet(Duration newAssetsLockDuration);

    /// @notice Stores the context of the state of the Escrow instance
    /// @param state The current state of the Escrow instance
    /// @param minAssetsLockDuration The minimum time required to pass before tokens can be unlocked from the Escrow
    ///        contract instance
    /// @param rageQuitExtensionDelay The period of time that starts after all withdrawal batches are formed, which delays
    ///        the exit from the RageQuit state of the DualGovernance. The main purpose of the rage quit extension delay is to provide
    ///        enough time for users who locked their unstETH to claim it.
    struct Context {
        /// @dev slot0: [0..7]
        State state;
        /// @dev slot0: [8..39]
        Duration minAssetsLockDuration;
        /// @dev slot0: [40..71]
        Duration rageQuitExtensionDelay;
        /// @dev slot0: [72..111]
        Timestamp rageQuitExtensionDelayStartedAt;
        /// @dev slot0: [112..143]
        Duration rageQuitWithdrawalsTimelock;
    }

    /// @notice Initializes the Escrow state to SignallingEscrow
    /// @param self The context of the Escrow instance
    /// @param minAssetsLockDuration The minimum assets lock duration
    function initialize(Context storage self, Duration minAssetsLockDuration) internal {
        _checkState(self, State.NotInitialized);
        _setState(self, State.SignallingEscrow);
        _setMinAssetsLockDuration(self, minAssetsLockDuration);
    }

    /// @notice Starts the rage quit process
    /// @param self The context of the Escrow instance
    /// @param rageQuitExtensionDelay The delay period for the rage quit extension
    /// @param rageQuitWithdrawalsTimelock The timelock period for rage quit withdrawals
    function startRageQuit(
        Context storage self,
        Duration rageQuitExtensionDelay,
        Duration rageQuitWithdrawalsTimelock
    ) internal {
        _checkState(self, State.SignallingEscrow);
        _setState(self, State.RageQuitEscrow);
        self.rageQuitExtensionDelay = rageQuitExtensionDelay;
        self.rageQuitWithdrawalsTimelock = rageQuitWithdrawalsTimelock;
        emit RageQuitStarted(rageQuitExtensionDelay, rageQuitWithdrawalsTimelock);
    }

    /// @notice Starts the rage quit extension delay
    /// @param self The context of the Escrow instance
    function startRageQuitExtensionDelay(Context storage self) internal {
        self.rageQuitExtensionDelayStartedAt = Timestamps.now();
        emit RageQuitTimelockStarted(self.rageQuitExtensionDelayStartedAt);
    }

    /// @notice Sets the minimum assets lock duration
    /// @param self The context of the Escrow instance
    /// @param newMinAssetsLockDuration The new minimum assets lock duration
    function setMinAssetsLockDuration(Context storage self, Duration newMinAssetsLockDuration) internal {
        if (self.minAssetsLockDuration == newMinAssetsLockDuration) {
            revert InvalidMinAssetsLockDuration(newMinAssetsLockDuration);
        }
        _setMinAssetsLockDuration(self, newMinAssetsLockDuration);
    }

    // ---
    // Checks
    // ---

    /// @notice Checks if the Escrow is in the SignallingEscrow state
    /// @param self The context of the Escrow instance
    function checkSignallingEscrow(Context storage self) internal view {
        _checkState(self, State.SignallingEscrow);
    }

    /// @notice Checks if the Escrow is in the RageQuitEscrow state
    /// @param self The context of the Escrow instance
    function checkRageQuitEscrow(Context storage self) internal view {
        _checkState(self, State.RageQuitEscrow);
    }

    /// @notice Checks if batch claiming is in progress
    /// @param self The context of the Escrow instance
    function checkBatchesClaimingInProgress(Context storage self) internal view {
        if (!self.rageQuitExtensionDelayStartedAt.isZero()) {
            revert ClaimingIsFinished();
        }
    }

    /// @notice Checks if the withdrawals timelock has passed
    /// @param self The context of the Escrow instance
    function checkWithdrawalsTimelockPassed(Context storage self) internal view {
        if (self.rageQuitExtensionDelayStartedAt.isZero()) {
            revert RageQuitExtraTimelockNotStarted();
        }
        Duration withdrawalsTimelock = self.rageQuitExtensionDelay + self.rageQuitWithdrawalsTimelock;
        if (Timestamps.now() <= withdrawalsTimelock.addTo(self.rageQuitExtensionDelayStartedAt)) {
            revert WithdrawalsTimelockNotPassed();
        }
    }

    // ---
    // Getters
    // ---

    /// @notice Checks if the rage quit extension delay has started
    /// @param self The context of the Escrow instance
    /// @return True if the rage quit extension delay has started, false otherwise
    function isRageQuitExtensionDelayStarted(Context storage self) internal view returns (bool) {
        return self.rageQuitExtensionDelayStartedAt.isNotZero();
    }

    /// @notice Checks if the rage quit extension delay has passed
    /// @param self The context of the Escrow instance
    /// @return True if the rage quit extension delay has passed, false otherwise
    function isRageQuitExtensionDelayPassed(Context storage self) internal view returns (bool) {
        Timestamp rageQuitExtensionDelayStartedAt = self.rageQuitExtensionDelayStartedAt;
        return rageQuitExtensionDelayStartedAt.isNotZero()
            && Timestamps.now() > self.rageQuitExtensionDelay.addTo(rageQuitExtensionDelayStartedAt);
    }

    /// @notice Checks if the Escrow is in the RageQuitEscrow state
    /// @param self The context of the Escrow instance
    /// @return True if the Escrow is in the RageQuitEscrow state, false otherwise
    function isRageQuitEscrow(Context storage self) internal view returns (bool) {
        return self.state == State.RageQuitEscrow;
    }

    // ---
    // Private Methods
    // ---

    /// @notice Checks if the Escrow is in the expected state
    /// @param self The context of the Escrow instance
    /// @param state The expected state
    function _checkState(Context storage self, State state) private view {
        if (self.state != state) {
            revert UnexpectedState(state);
        }
    }

    /// @notice Sets the state of the Escrow
    /// @param self The context of the Escrow instance
    /// @param newState The new state
    function _setState(Context storage self, State newState) private {
        State prevState = self.state;
        self.state = newState;
        emit EscrowStateChanged(prevState, newState);
    }

    /// @notice Sets the minimum assets lock duration
    /// @param self The context of the Escrow instance
    /// @param newMinAssetsLockDuration The new minimum assets lock duration
    function _setMinAssetsLockDuration(Context storage self, Duration newMinAssetsLockDuration) private {
        self.minAssetsLockDuration = newMinAssetsLockDuration;
        emit MinAssetsLockDurationSet(newMinAssetsLockDuration);
    }
}
