pragma solidity 0.8.26;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

//import "contracts/Configuration.sol";
import "contracts/DualGovernance.sol";
import "contracts/EmergencyProtectedTimelock.sol";
import {Escrow} from "contracts/Escrow.sol";

import {addTo, Duration, Durations} from "contracts/types/Duration.sol";
import {PercentD16} from "contracts/types/PercentD16.sol";
import {Timestamp, Timestamps} from "contracts/types/Timestamp.sol";

import "contracts/model/StETHModel.sol";
import "contracts/model/WithdrawalQueueModel.sol";
import "contracts/model/WstETHAdapted.sol";

import {StorageSetup} from "test/kontrol/StorageSetup.sol";
import {DualGovernanceSetUp} from "test/kontrol/DualGovernanceSetUp.sol";
import {EscrowInvariants} from "test/kontrol/EscrowInvariants.sol";

import "kontrol-cheatcodes/KontrolCheats.sol";

contract EscrowLockUnlockTest is EscrowInvariants, DualGovernanceSetUp {
    function _assumeFreshAddress(address account) internal {
        IEscrowBase escrow = signallingEscrow;
        vm.assume(account != address(0));
        vm.assume(account != address(this));
        vm.assume(account != address(vm));
        vm.assume(account != address(kevm));
        vm.assume(account != address(stEth));
        vm.assume(account != address(escrow)); // Important assumption: could potentially violate invariants if violated

        // Keccak injectivity
        vm.assume(
            keccak256(abi.encodePacked(account, uint256(2))) != keccak256(abi.encodePacked(address(escrow), uint256(2)))
        );
    }

    function testLockStEth(uint256 amount) public {
        // Placeholder address to avoid complications with keccak of symbolic addresses
        address sender = address(uint160(uint256(keccak256("sender"))));

        {
            uint256 senderShares = freshUInt256();
            vm.assume(senderShares < ethUpperBound);
            stEth.setShares(sender, senderShares);
            vm.assume(stEth.balanceOf(sender) < ethUpperBound);

            uint256 senderAllowance = freshUInt256();
            // This assumption means that senderAllowance != INFINITE_ALLOWANCE,
            // which doubles the execution effort without any added vaue
            vm.assume(senderAllowance < ethUpperBound);
            stEth.setAllowances(sender, address(signallingEscrow), senderAllowance);

            this.escrowUserSetup(signallingEscrow, sender);

            vm.assume(senderShares + stEth.sharesOf(address(signallingEscrow)) <= stEth.getTotalShares());

            vm.assume(0 < amount);
            vm.assume(amount <= stEth.balanceOf(sender));
            vm.assume(amount <= senderAllowance);
        }

        AccountingRecord memory pre = this.saveAccountingRecord(sender, signallingEscrow);

        uint256 amountInShares = stEth.getSharesByPooledEth(amount);
        vm.assume(0 < amountInShares);

        this.escrowInvariants(Mode.Assume, signallingEscrow);
        this.signallingEscrowInvariants(Mode.Assume, signallingEscrow);
        this.escrowUserInvariants(Mode.Assume, signallingEscrow, sender);

        {
            State initialState = dualGovernance.getPersistedState();

            // Information to help forget first state transition
            PercentD16 init_rageQuitSupport = signallingEscrow.getRageQuitSupport();
            Timestamp init_vetoSignallingActivatedAt = Timestamp.wrap(_getVetoSignallingActivationTime(dualGovernance));
            Timestamp init_vetoSignallingReactivationTime =
                Timestamp.wrap(_getVetoSignallingReactivationTime(dualGovernance));
            Timestamp init_enteredAt = Timestamp.wrap(_getEnteredAt(dualGovernance));
            Timestamp init_rageQuitExtensionPeriodStartedAt =
                Timestamp.wrap(_getRageQuitExtensionPeriodStartedAt(rageQuitEscrow));
            Duration init_rageQuitExtensionPeriodDuration =
                Duration.wrap(_getRageQuitExtensionPeriodDuration(rageQuitEscrow));

            State nextState = dualGovernance.getEffectiveState();
            vm.assume(initialState == State.RageQuit || nextState != State.RageQuit);

            vm.startPrank(sender);
            signallingEscrow.lockStETH(amount);
            vm.stopPrank();

            // Information to help forget second state transition
            PercentD16 next_rageQuitSupport = signallingEscrow.getRageQuitSupport();
            Timestamp next_vetoSignallingActivatedAt = Timestamp.wrap(_getVetoSignallingActivationTime(dualGovernance));
            Timestamp next_vetoSignallingReactivationTime =
                Timestamp.wrap(_getVetoSignallingReactivationTime(dualGovernance));
            Timestamp next_enteredAt = Timestamp.wrap(_getEnteredAt(dualGovernance));
            Timestamp next_rageQuitExtensionPeriodStartedAt =
                Timestamp.wrap(_getRageQuitExtensionPeriodStartedAt(rageQuitEscrow));
            Duration next_rageQuitExtensionPeriodDuration =
                Duration.wrap(_getRageQuitExtensionPeriodDuration(rageQuitEscrow));

            // Forget correctness constraints
            kevm.forgetBranch(
                PercentD16.unwrap(init_rageQuitSupport), KontrolCheatsBase.ComparisonOperator.LessThan, 2 ** 128
            );

            // Forget second state transition
            this.forgetStateTransition(
                nextState,
                next_rageQuitSupport,
                next_vetoSignallingActivatedAt,
                next_vetoSignallingReactivationTime,
                next_enteredAt,
                next_rageQuitExtensionPeriodStartedAt,
                next_rageQuitExtensionPeriodDuration
            );

            // Forget first state transition
            this.forgetStateTransition(
                initialState,
                init_rageQuitSupport,
                init_vetoSignallingActivatedAt,
                init_vetoSignallingReactivationTime,
                init_enteredAt,
                init_rageQuitExtensionPeriodStartedAt,
                init_rageQuitExtensionPeriodDuration
            );
        }

        this.escrowInvariants(Mode.Assert, signallingEscrow);
        this.signallingEscrowInvariants(Mode.Assert, signallingEscrow);
        this.escrowUserInvariants(Mode.Assert, signallingEscrow, sender);

        AccountingRecord memory post = this.saveAccountingRecord(sender, signallingEscrow);
        assert(post.userShares == pre.userShares - amountInShares);
        assert(post.escrowShares == pre.escrowShares + amountInShares);
        assert(post.userSharesLocked == pre.userSharesLocked + amountInShares);
        assert(post.totalSharesLocked == pre.totalSharesLocked + amountInShares);
        assert(post.userLastLockedTime == Timestamps.now());

        // Accounts for rounding errors in the conversion to and from shares
        uint256 errorTerm = stEth.getPooledEthByShares(1) + 1;

        assert(pre.userBalance - amount <= post.userBalance);
        assert(post.userBalance <= pre.userBalance - amount + errorTerm);

        assert(post.escrowBalance <= pre.escrowBalance + amount);
        assert(pre.escrowBalance + amount <= post.escrowBalance + errorTerm);

        assert(post.totalEth <= pre.totalEth + amount);
        assert(pre.totalEth + amount <= post.totalEth + errorTerm);
    }

    //
    function testUnlockStEth() public {
        // Placeholder address to avoid complications with keccak of symbolic addresses
        address sender = address(uint160(uint256(keccak256("sender"))));
        uint256 senderShares = freshUInt256();
        vm.assume(senderShares < ethUpperBound);
        stEth.setShares(sender, senderShares);
        vm.assume(stEth.balanceOf(sender) < ethUpperBound);

        uint256 senderAllowance = freshUInt256();
        // This assumption means that senderAllowance != INFINITE_ALLOWANCE,
        // which doubles the execution effort without any added vaue
        vm.assume(senderAllowance < ethUpperBound);
        // Hardcoded for "sender"
        _storeUInt256(
            address(stEth),
            74992941968319547325319283905569341819227548318746972755481050864341498730161,
            senderAllowance
        );

        uint256 senderLockedShares = freshUInt256();
        vm.assume(senderLockedShares < ethUpperBound);
        uint256 senderUnlockedShares = freshUInt256();
        bytes memory slotAbi = abi.encodePacked(uint128(senderUnlockedShares), uint128(senderLockedShares));
        bytes32 slot;
        assembly {
            slot := mload(add(slotAbi, 0x20))
        }
        _storeBytes32(
            address(signallingEscrow),
            93842437974268059396725027201531251382101332839645030345425397622830526343272,
            slot
        );

        uint256 senderLastAssetsLockTimestamp = freshUInt256();
        vm.assume(senderLastAssetsLockTimestamp < timeUpperBound);
        _storeUInt256(
            address(signallingEscrow),
            93842437974268059396725027201531251382101332839645030345425397622830526343273,
            senderLastAssetsLockTimestamp
        );

        AccountingRecord memory pre = this.saveAccountingRecord(sender, signallingEscrow);
        vm.assume(0 < pre.userSharesLocked);
        vm.assume(pre.userSharesLocked <= pre.totalSharesLocked);
        vm.assume(
            Timestamps.now() > addTo(Duration.wrap(_getMinAssetsLockDuration(signallingEscrow)), pre.userLastLockedTime)
        );

        this.escrowInvariants(Mode.Assume, signallingEscrow);
        this.signallingEscrowInvariants(Mode.Assume, signallingEscrow);
        this.escrowUserInvariants(Mode.Assume, signallingEscrow, sender);

        bool transitionToRageQuit;

        {
            State initialState = dualGovernance.getPersistedState();
            PercentD16 rageQuitSupport = signallingEscrow.getRageQuitSupport();
            Timestamp vetoSignallingActivationTime = Timestamp.wrap(_getVetoSignallingActivationTime(dualGovernance));

            transitionToRageQuit = (
                initialState == State.VetoSignalling || initialState == State.VetoSignallingDeactivation
            ) && rageQuitSupport > config.SECOND_SEAL_RAGE_QUIT_SUPPORT()
                && Timestamps.now() > config.VETO_SIGNALLING_MAX_DURATION().addTo(vetoSignallingActivationTime);
        }

        vm.assume(!transitionToRageQuit);

        /*
        ActivateNextStateMock mock = new ActivateNextStateMock(address(this), sender);
        kevm.mockFunction(
            address(dualGovernance), address(mock), abi.encodeWithSelector(mock.activateNextState.selector)
        );
        */

        vm.startPrank(sender);
        signallingEscrow.unlockStETH();
        vm.stopPrank();

        this.escrowInvariants(Mode.Assert, signallingEscrow);
        this.signallingEscrowInvariants(Mode.Assert, signallingEscrow);
        this.escrowUserInvariants(Mode.Assert, signallingEscrow, sender);

        AccountingRecord memory post = this.saveAccountingRecord(sender, signallingEscrow);
        assert(post.userShares == pre.userShares + pre.userSharesLocked);
        assert(post.userSharesLocked == 0);
        assert(post.totalSharesLocked == pre.totalSharesLocked - pre.userSharesLocked);
        assert(post.userLastLockedTime == pre.userLastLockedTime);

        // Accounts for rounding errors in the conversion to and from shares
        uint256 amount = stEth.getPooledEthByShares(pre.userSharesLocked);

        // Rewritten to avoid branching
        //assert(pre.escrowBalance - amount < 1 || pre.escrowBalance - amount - 1 <= post.escrowBalance);
        assert(pre.escrowBalance - amount <= post.escrowBalance + 1);
        assert(post.escrowBalance <= pre.escrowBalance - amount);

        // Rewritten to avoid branching
        //assert(pre.totalEth - amount < 1 || pre.totalEth - amount - 1 <= post.totalEth);
        assert(pre.totalEth - amount <= post.totalEth + 1);
        assert(post.totalEth <= pre.totalEth - amount);

        assert(pre.userBalance + amount <= post.userBalance);
        assert(post.userBalance <= pre.userBalance + amount + 1);
    }
}
