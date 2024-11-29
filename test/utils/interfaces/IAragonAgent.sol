// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IAragonForwarder} from "./IAragonForwarder.sol";

interface IAragonAgent is IAragonForwarder {
    function EXECUTE_ROLE() external pure returns (bytes32);
    function RUN_SCRIPT_ROLE() external pure returns (bytes32);
}
