// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockLegacyPool {
    IERC20 yfv;

    constructor(IERC20 _yfv) public {
        yfv = _yfv;
    }

    function setRewardStake(address _rewardStake) external {
        yfv.approve(_rewardStake, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    }
}
