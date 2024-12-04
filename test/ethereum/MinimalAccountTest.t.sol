// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {HelperConfig, NetworkConfig} from "script/HelperConfig.s.sol";
import {DeployMinimalAccount} from "script/DeployMinimalAccount.s.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "script/SendPackedUserOp.s.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    NetworkConfig cfg;
    MinimalAccount minimalAccount;
    SendPackedUserOp sendPackedUserOp;

    address randomuser = makeAddr("randomUser");

    uint256 constant USDC_AMOUNT = 10 ether;
    uint256 constant MISSING_ACCOUNT_FUNDS = 1 ether;

    function setUp() public {
        HelperConfig helperConfig;
        DeployMinimalAccount deployer = new DeployMinimalAccount();
        (helperConfig, minimalAccount) = deployer.deployMinimalAccount();
        cfg = helperConfig.getConfig();
        sendPackedUserOp = new SendPackedUserOp();

        vm.deal(address(minimalAccount), MISSING_ACCOUNT_FUNDS);
    }

    function signUserOp() public view returns (PackedUserOperation memory packedUserOp, bytes32 userOperationHash) {
        address dest = cfg.usdc;
        uint256 value = 0;
        bytes memory functionData =
            abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), USDC_AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData, cfg, address(minimalAccount));
        userOperationHash = IEntryPoint(cfg.entryPoint).getUserOpHash(packedUserOp);
    }

    function testOwnerCanExecuteCommands() public {
        // Arrange
        address dest = cfg.usdc;
        uint256 value = 0;
        bytes memory functionData =
            abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), USDC_AMOUNT);
        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);

        // Assert
        assertEq(IERC20(cfg.usdc).balanceOf(address(minimalAccount)), USDC_AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        // Arrange
        address dest = cfg.usdc;
        uint256 value = 0;
        bytes memory functionData =
            abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), USDC_AMOUNT);
        // Act
        vm.prank(randomuser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() public view {
        (PackedUserOperation memory packedUserOp, bytes32 userOperationHash) = signUserOp();
        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        assertEq(actualSigner, minimalAccount.owner());
    }

    function testValidationOfUserOps() public {
        (PackedUserOperation memory packedUserOp, bytes32 userOperationHash) = signUserOp();

        vm.prank(cfg.entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOperationHash, MISSING_ACCOUNT_FUNDS);

        assertEq(validationData, 0);
        assertEq(cfg.entryPoint.balance, MISSING_ACCOUNT_FUNDS);
    }

    function testValidationOfUserOpsInvalidSignature() public {
        (PackedUserOperation memory packedUserOp, bytes32 userOperationHash) = signUserOp();
        packedUserOp.signature[0] = ~packedUserOp.signature[0];

        vm.prank(cfg.entryPoint);
        vm.expectRevert(ECDSA.ECDSAInvalidSignature.selector);
        minimalAccount.validateUserOp(packedUserOp, userOperationHash, MISSING_ACCOUNT_FUNDS);

        assertEq(cfg.entryPoint.balance, 0);
    }

    function testEntryPointCanExecuteCommands() public {
        // Arrange
        (PackedUserOperation memory packedUserOp,) = signUserOp();
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        // Act
        // As long as we signed the operation, it doesn't matter who sends it to the entrypoint
        vm.prank(randomuser);
        IEntryPoint(cfg.entryPoint).handleOps(ops, payable(randomuser));

        // Assert
        assertEq(IERC20(cfg.usdc).balanceOf(address(minimalAccount)), USDC_AMOUNT);
    }
}
