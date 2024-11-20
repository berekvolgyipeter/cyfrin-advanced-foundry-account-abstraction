// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IAccount } from "account-abstraction/interfaces/IAccount.sol";
import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";
import { SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS } from "account-abstraction/core/Helpers.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { MessageHashUtils } from "openzeppelin/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "openzeppelin/utils/cryptography/ECDSA.sol";

contract MinimalAccount is IAccount, Ownable {
    constructor(address entryPoint) Ownable(msg.sender) { }

    /**
     * 1. The purpose of this function is to validate user operations by ensuring that the signature is valid. It also
     * handles missing account funds. A signature is valid, if it's the MinimalAccount owner.
     *
     *  2. It verifies the signer's address by first converting the `userOpHash` into a signed message hash. It then
     * recovers the signer's address using ECDSA.recover with the signed message hash and the signature from userOp.
     * Finally, it compares the recovered address to the owner's address to determine if the signature is valid.
     *
     *  3. We need OpenZeppelin's Ownable contract to manage ownership of the contract, ensuring that only the owner can
     * validate signatures.
     *
     *  4. This function handles the payment of missing account funds owed to the EntryPoint. It checks if there are any
     * missing funds and, if so, pays what is owed.
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        /// @dev _validateNonce() will be handled by the `EntryPoint` contract
        _payPrefund(missingAccountFunds);
    }

    // EIP-191 version of the signed hash
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        internal
        view
        returns (uint256 validationData)
    {
        // convert the `userOpHash` back into a normal hash
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{ value: missingAccountFunds, gas: type(uint256).max }("");
            (success);
        }
    }
}
