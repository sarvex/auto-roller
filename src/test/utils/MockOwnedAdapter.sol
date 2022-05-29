// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

import { Trust } from "sense-v1-utils/Trust.sol";
import { BaseAdapter } from "sense-v1-core/adapters/BaseAdapter.sol";

import { AutoRoller, SpaceFactoryLike, OwnableAdapter } from "../../AutoRoller.sol";

interface Opener {
    function onSponsorWindowOpened() external;
}

contract MockAdapter is OwnableAdapter, Trust{
    uint256 public override scale = 1.1e18;
    uint256 internal open = 1;

    constructor(
        address _divider,
        address _target,
        address _underlying,
        AdapterParams memory _adapterParams
    ) BaseAdapter(_divider, _target, _underlying, 0 /* no issuance fee */, _adapterParams) Trust(msg.sender) { }

    function scaleStored() external view virtual override returns (uint256 _scale) {
        _scale = scale;
    }

    function wrapUnderlying(uint256 uBal) external virtual override returns (uint256 amountOut) {
        MockERC20 target = MockERC20(target);
        MockERC20 underlying = MockERC20(underlying);

        uint256 tDecimals = target.decimals();
        uint256 uDecimals = underlying.decimals();

        underlying.transferFrom(msg.sender, address(this), uBal);
        amountOut = uDecimals < tDecimals ? 
            uBal * 1e18 / scale * (tDecimals - uDecimals) ** 10 :
            uBal * 1e18 / scale / (uDecimals - tDecimals) ** 10;

        target.mint(msg.sender, amountOut);
    }

    function unwrapTarget(uint256 tBal) external virtual override returns (uint256 amountOut) {
        MockERC20 target = MockERC20(target);
        MockERC20 underlying = MockERC20(underlying);

        uint256 tDecimals = target.decimals();
        uint256 uDecimals = underlying.decimals();

        target.transferFrom(msg.sender, address(this), tBal);
        amountOut = uDecimals < tDecimals ? 
            tBal * scale / 1e18 / (tDecimals - uDecimals) ** 10 :
            tBal * scale / 1e18 * (uDecimals - tDecimals) ** 10;
            
        underlying.mint(msg.sender, amountOut);
    }

    function getUnderlyingPrice() external view virtual override returns (uint256) {
        return 1e18;
    }

    function setScale(uint256 _scale) external {
        scale = _scale;
    }

    function openSponsorWindow() external override requiresTrust {
        open = 2;
        Opener(msg.sender).onSponsorWindowOpened();
        open = 1;
    }

    function getMaturityBounds() external view override returns (uint256, uint256) {
        return open == 2 ? (0, type(uint64).max / 2) : (0, 0);
    }
}