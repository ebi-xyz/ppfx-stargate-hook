// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IPPFX} from "../src/IPPFX.sol";
import {PPFXStargateWithdrawHook} from "../src/PPFXStargateWithdrawHook.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract USDT is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(_msgSender(), 100_000_000 ether);
    }
}

contract PPFXStargateWithdrawHookTest is Test {

    error OwnableUnauthorizedAccount(address account);

    PPFXStargateWithdrawHook public ppfxWithdrawHook;
    USDT public usdt;

    address public treasury = address(123400);
    address public fakePPFX = address(333333);
    address public fakeStargate = address(555555);

    function setUp() public {
        usdt = new USDT("USDT", "USDT");
        
        ppfxWithdrawHook = new PPFXStargateWithdrawHook(
            IPPFX(fakePPFX),
            address(1),
            treasury,
            fakeStargate
        );
    }

    function test_SuccessAddOperator() public {
        assertEq(ppfxWithdrawHook.getAllOperators().length, 0);
        vm.startPrank(address(1));
        ppfxWithdrawHook.addOperator(address(2));
        assertEq(ppfxWithdrawHook.isOperator(address(2)), true);
        vm.stopPrank();
    }

    function test_SuccessRemoveOperator() public {
        assertEq(ppfxWithdrawHook.getAllOperators().length, 0);
        vm.startPrank(address(1));

        ppfxWithdrawHook.addOperator(address(2));
        assertEq(ppfxWithdrawHook.isOperator(address(2)), true);

        ppfxWithdrawHook.removeOperator(address(2));
        assertEq(ppfxWithdrawHook.isOperator(address(2)), false);

        vm.stopPrank();
    }

    function test_SuccessRemoveAllOperator() public {
        assertEq(ppfxWithdrawHook.getAllOperators().length, 0);
        vm.startPrank(address(1));

        ppfxWithdrawHook.addOperator(address(1));
        ppfxWithdrawHook.addOperator(address(2));
        ppfxWithdrawHook.addOperator(address(3));

        assertEq(ppfxWithdrawHook.getAllOperators().length, 3);

        ppfxWithdrawHook.removeAllOperator();
        assertEq(ppfxWithdrawHook.getAllOperators().length, 0);

        vm.stopPrank();
    }

    function test_SuccessTransferOwnership() public {
        vm.startPrank(address(1));
        ppfxWithdrawHook.transferOwnership(address(2));
        assertEq(ppfxWithdrawHook.pendingOwner(), address(2));
        vm.stopPrank();
    }

    function test_SuccessAcceptOwnership() public {
        vm.startPrank(address(1));
        ppfxWithdrawHook.transferOwnership(address(2));
        assertEq(ppfxWithdrawHook.pendingOwner(), address(2));
        vm.stopPrank();
        vm.startPrank(address(2));
        ppfxWithdrawHook.acceptOwnership();
        assertEq(ppfxWithdrawHook.owner(), address(2));
        vm.stopPrank();
    }

    function test_SuccessSweepToken() public {
        usdt.transfer(address(ppfxWithdrawHook), 1 ether);
        assertEq(usdt.balanceOf(address(ppfxWithdrawHook)), 1 ether);

        vm.startPrank(address(1));
        ppfxWithdrawHook.sweepToken(usdt);
        assertEq(usdt.balanceOf(address(1)), 1 ether);
        vm.stopPrank();
    }

    function test_SuccessUpdateTreasury() public {
        vm.startPrank(address(1));
        ppfxWithdrawHook.updateTreasury(address(2));
        assertEq(ppfxWithdrawHook.treasury(), address(2));
        vm.stopPrank();
    }

    function test_Fail_NotOwner_AddOperator() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        ppfxWithdrawHook.addOperator(address(2));
    }

    function test_Fail_NotOwner_UpdateTreasury() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        ppfxWithdrawHook.updateTreasury(address(2));
    }

    function test_Fail_NotOwner_RemoveOperator() public {
        vm.startPrank(address(1));
        ppfxWithdrawHook.addOperator(address(2));
        assertEq(ppfxWithdrawHook.isOperator(address(2)), true);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        ppfxWithdrawHook.removeOperator(address(2));
    }

    function test_Fail_NotOwner_RemoveAllOperators() public {
        vm.startPrank(address(1));
        ppfxWithdrawHook.addOperator(address(2));
        assertEq(ppfxWithdrawHook.isOperator(address(2)), true);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        ppfxWithdrawHook.removeAllOperator();
    }

    function test_Fail_NotOwner_SweepToken() public {
        usdt.transfer(address(ppfxWithdrawHook), 1 ether);
        assertEq(usdt.balanceOf(address(ppfxWithdrawHook)), 1 ether);

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        ppfxWithdrawHook.sweepToken(usdt);
    }
}
