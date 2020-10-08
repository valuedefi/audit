// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ValueLiquidityToken.sol";

interface ILiquidityMigrator {
    // Perform LP token migration from legacy Balancer to ValueLiquid.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to Balancer LP tokens.
    // ValueLiquid must mint EXACTLY the same amount of Balancer LP tokens or
    // else something bad will happen. Traditional Balancer does not
    // do that so be careful!
    function migrate(IERC20 token) external returns (IERC20);
}

interface IYFVReferral {
    function setReferrer(address farmer, address referrer) external;
    function getReferrer(address farmer) external view returns (address);
}

interface IFreeFromUpTo {
    function freeFromUpTo(address from, uint256 value) external returns (uint256 freed);
}

// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract (Timelock multisig signers) once VALUE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract ValueMasterPool is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IFreeFromUpTo public constant chi = IFreeFromUpTo(0x0000000000004946c0e9F43F4Dee607b0eF1fA1c);
    modifier discountCHI {
        uint256 gasStart = gasleft();
        _;
        uint256 gasSpent = 21000 + gasStart - gasleft() + 16 * msg.data.length;
        chi.freeFromUpTo(msg.sender, (gasSpent + 14154) / 41130);
    }
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of VALUEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accValuePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accValuePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
        uint256 accumulatedStakingPower; // will accumulate every time user harvest
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. VALUEs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that VALUEs distribution occurs.
        uint256 accValuePerShare; // Accumulated VALUEs per share, times 1e12. See below.
        bool isStarted; // if lastRewardBlock has passed
    }
    uint256 public constant REFERRAL_COMMISSION_PERCENT = 1;
    address public rewardReferral;
    // The VALUE TOKEN!
    ValueLiquidityToken public value;
    // InsuranceFund address.
    address public insuranceFundAddr;
    // VALUE tokens created per block.
    uint256 public valuePerBlock;
    // The liquidity migrator contract. It has a lot of power. Can only be set through governance (owner).
    ILiquidityMigrator public migrator;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when VALUE mining starts.
    uint256 public startBlock;
    // Block number when each epoch ends.
    uint256[3] public epochEndBlocks = [10887300, 11080000, 20000000];
    // Reward multipler
    uint256[4] public epochRewardMultiplers = [5000, 10000, 1, 0];

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        ValueLiquidityToken _value,
        address _insuranceFundAddr,
        uint256 _valuePerBlock,
        uint256 _startBlock
    ) public {
        value = _value;
        insuranceFundAddr = _insuranceFundAddr;
        valuePerBlock = _valuePerBlock; // supposed to be 0.001 (1e16 wei)
        startBlock = _startBlock; // supposed to be 10,883,800 (Fri Sep 18 2020 3:00:00 GMT+0)
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate, uint256 _lastRewardBlock) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        if (block.number < startBlock) {
            // chef is sleeping
            if (_lastRewardBlock == 0) {
                _lastRewardBlock = startBlock;
            } else {
                if (_lastRewardBlock < startBlock) {
                    _lastRewardBlock = startBlock;
                }
            }
        } else {
            // chef is cooking
            if (_lastRewardBlock == 0 || _lastRewardBlock < block.number) {
                _lastRewardBlock = block.number;
            }
        }
        bool _isStarted = (block.number >= _lastRewardBlock) && (_lastRewardBlock >= startBlock);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: _lastRewardBlock,
            accValuePerShare: 0,
            isStarted: _isStarted
            }));
        if (_isStarted) {
            totalAllocPoint = totalAllocPoint.add(_allocPoint);
        }
    }

    // Update the given pool's VALUE allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.isStarted) {
            totalAllocPoint = totalAllocPoint.sub(pool.allocPoint).add(_allocPoint);
        }
        pool.allocPoint = _allocPoint;
    }

    function setValuePerBlock(uint256 _valuePerBlock) public onlyOwner {
        massUpdatePools();
        valuePerBlock = _valuePerBlock;
    }

    function setEpochEndBlock(uint8 _index, uint256 _epochEndBlock) public onlyOwner {
        require(_index < 3, "_index out of range");
        require(_epochEndBlock > block.number, "Too late to update");
        require(epochEndBlocks[_index] > block.number, "Too late to update");
        epochEndBlocks[_index] = _epochEndBlock;
    }

    function setEpochRewardMultipler(uint8 _index, uint256 _epochRewardMultipler) public onlyOwner {
        require(_index > 0 && _index < 4, "Index out of range");
        require(epochEndBlocks[_index - 1] > block.number, "Too late to update");
        epochRewardMultiplers[_index] = _epochRewardMultipler;
    }

    function setRewardReferral(address _rewardReferral) external onlyOwner {
        rewardReferral = _rewardReferral;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(ILiquidityMigrator _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract.
    function migrate(uint256 _pid) public onlyOwner {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        for (uint8 epochId = 3; epochId >= 1; --epochId) {
            if (_to >= epochEndBlocks[epochId - 1]) {
                if (_from >= epochEndBlocks[epochId - 1]) return _to.sub(_from).mul(epochRewardMultiplers[epochId]);
                uint256 multiplier = _to.sub(epochEndBlocks[epochId - 1]).mul(epochRewardMultiplers[epochId]);
                if (epochId == 1) return multiplier.add(epochEndBlocks[0].sub(_from).mul(epochRewardMultiplers[0]));
                for (epochId = epochId - 1; epochId >= 1; --epochId) {
                    if (_from >= epochEndBlocks[epochId - 1]) return multiplier.add(epochEndBlocks[epochId].sub(_from).mul(epochRewardMultiplers[epochId]));
                    multiplier = multiplier.add(epochEndBlocks[epochId].sub(epochEndBlocks[epochId - 1]).mul(epochRewardMultiplers[epochId]));
                }
                return multiplier.add(epochEndBlocks[0].sub(_from).mul(epochRewardMultiplers[0]));
            }
        }
        return _to.sub(_from).mul(epochRewardMultiplers[0]);
    }

    // View function to see pending VALUEs on frontend.
    function pendingValue(uint256 _pid, address _user) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accValuePerShare = pool.accValuePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            if (totalAllocPoint > 0) {
                uint256 valueReward = multiplier.mul(valuePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
                accValuePerShare = accValuePerShare.add(valueReward.mul(1e12).div(lpSupply));
            }
        }
        return user.amount.mul(accValuePerShare).div(1e12).sub(user.rewardDebt);
    }

    function stakingPower(uint256 _pid, address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        return user.accumulatedStakingPower.add(pendingValue(_pid, _user));
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public discountCHI {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public discountCHI {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        if (!pool.isStarted) {
            pool.isStarted = true;
            totalAllocPoint = totalAllocPoint.add(pool.allocPoint);
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        if (totalAllocPoint > 0) {
            uint256 valueReward = multiplier.mul(valuePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            safeValueMint(address(this), valueReward);
            pool.accValuePerShare = pool.accValuePerShare.add(valueReward.mul(1e12).div(lpSupply));
        }
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to ValueMasterPool for VALUE allocation.
    function deposit(uint256 _pid, uint256 _amount, address _referrer) public discountCHI {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (rewardReferral != address(0) && _referrer != address(0)) {
            require(_referrer != msg.sender, "You cannot refer yourself.");
            IYFVReferral(rewardReferral).setReferrer(msg.sender, _referrer);
        }
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accValuePerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                user.accumulatedStakingPower = user.accumulatedStakingPower.add(pending);
                uint256 actualPaid = pending.mul(100 - REFERRAL_COMMISSION_PERCENT).div(100); // 99%
                uint256 commission = pending - actualPaid; // 1%
                safeValueTransfer(msg.sender, actualPaid);
                if (rewardReferral != address(0)) {
                    _referrer = IYFVReferral(rewardReferral).getReferrer(msg.sender);
                }
                if (_referrer != address(0)) { // send commission to referrer
                    safeValueTransfer(_referrer, commission);
                } else { // send commission to insuranceFundAddr
                    safeValueTransfer(insuranceFundAddr, commission);
                }
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accValuePerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from ValueMasterPool.
    function withdraw(uint256 _pid, uint256 _amount) public discountCHI {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accValuePerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            user.accumulatedStakingPower = user.accumulatedStakingPower.add(pending);
            uint256 actualPaid = pending.mul(100 - REFERRAL_COMMISSION_PERCENT).div(100); // 99%
            uint256 commission = pending - actualPaid; // 1%
            safeValueTransfer(msg.sender, actualPaid);
            address _referrer = address(0);
            if (rewardReferral != address(0)) {
                _referrer = IYFVReferral(rewardReferral).getReferrer(msg.sender);
            }
            if (_referrer != address(0)) { // send commission to referrer
                safeValueTransfer(_referrer, commission);
            } else { // send commission to insuranceFundAddr
                safeValueTransfer(insuranceFundAddr, commission);
            }
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accValuePerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe value mint, ensure it is never over cap and we are the current owner.
    function safeValueMint(address _to, uint256 _amount) internal {
        if (value.minters(address(this)) && _to != address(0)) {
            uint256 totalSupply = value.totalSupply();
            uint256 realCap = value.cap().add(value.yfvLockedBalance());
            if (totalSupply.add(_amount) > realCap) {
                value.mint(_to, realCap.sub(totalSupply));
            } else {
                value.mint(_to, _amount);
            }
        }
    }

    // Safe value transfer function, just in case if rounding error causes pool to not have enough VALUEs.
    function safeValueTransfer(address _to, uint256 _amount) internal {
        uint256 valueBal = value.balanceOf(address(this));
        if (_amount > valueBal) {
            value.transfer(_to, valueBal);
        } else {
            value.transfer(_to, _amount);
        }
    }

    // Update insuranceFund by the previous insuranceFund contract.
    function setInsuranceFundAddr(address _insuranceFundAddr) public {
        require(msg.sender == insuranceFundAddr, "insuranceFund: wut?");
        insuranceFundAddr = _insuranceFundAddr;
    }

    // This function allows governance to take unsupported tokens out of the contract, since this pool exists longer than the other pools.
    // This is in an effort to make someone whole, should they seriously mess up.
    // There is no guarantee governance will vote to return these.
    // It also allows for removal of airdropped tokens.
    function governanceRecoverUnsupported(IERC20 _token, uint256 amount, address to) external onlyOwner {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            // cant take staked asset
            require(_token != pool.lpToken, "!pool.lpToken");
        }
        // transfer to
        _token.safeTransfer(to, amount);
    }
}
