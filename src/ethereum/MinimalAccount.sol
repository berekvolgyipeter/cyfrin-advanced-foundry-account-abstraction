// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IAccount } from "account-abstraction/interfaces/IAccount.sol";
import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";

contract MinimalAccount is IAccount {
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        returns (uint256 validationData)
    { }
}
