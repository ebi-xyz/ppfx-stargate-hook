// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IPPFX} from "../src/IPPFX.sol";
import {PPFXStargateDepositHook} from "../src/PPFXStargateDepositHook.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract USDT is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(_msgSender(), 100_000_000 ether);
    }
}

contract PPFXStargateDepositHookTest is Test {

    error OwnableUnauthorizedAccount(address account);

    PPFXStargateDepositHook public ppfxDepositHook;
    USDT public usdt;

    address public fakePPFX = address(333333);
    address public fakeLzEndpoint =  address(444444);
    address public fakeStargate = address(555555);

    function setUp() public {
        usdt = new USDT("USDT", "USDT");
        
        ppfxDepositHook = new PPFXStargateDepositHook(
            fakePPFX,
            fakeLzEndpoint,
            fakeStargate,
            address(1)
        );
    }

    function test_SuccessDepositHookSweepTokenFromAdmin() public {
        usdt.transfer(address(ppfxDepositHook), 1 ether);
        assertEq(usdt.balanceOf(address(ppfxDepositHook)), 1 ether);
        assertEq(usdt.balanceOf(address(1)), 0);
        vm.startPrank(address(1));
        ppfxDepositHook.sweepToken(IERC20(address(usdt)));
        vm.stopPrank();
        assertEq(usdt.balanceOf(address(1)), 1 ether);
    }

    function test_SuccessDepositHookTransferOwnership() public {
        assertEq(ppfxDepositHook.owner(), address(1));
        vm.startPrank(address(1));
        ppfxDepositHook.transferOwnership(address(2));
        assertEq(ppfxDepositHook.owner(), address(2));
        vm.stopPrank();
    }

    function test_FailDepositHookSweepTokenNoToken() public {
        vm.startPrank(address(1));
        vm.expectRevert(bytes("No Token to sweep"));
        ppfxDepositHook.sweepToken(IERC20(address(usdt)));
        vm.stopPrank();
    }

    function test_FailDepositHookSweepTokenNotAdmin() public {
        usdt.transfer(address(ppfxDepositHook), 1 ether);
        assertEq(usdt.balanceOf(address(ppfxDepositHook)), 1 ether);
        assertEq(usdt.balanceOf(address(1)), 0);
        
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        ppfxDepositHook.sweepToken(IERC20(address(usdt)));
    }

    function test_FailDepositHookTransferOwnershipNotOwner() public {
        assertEq(ppfxDepositHook.owner(), address(1));
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        ppfxDepositHook.transferOwnership(address(2));
    }
}
