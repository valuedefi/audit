/*
   ____            __   __        __   _
  / __/__ __ ___  / /_ / /  ___  / /_ (_)__ __
 _\ \ / // // _ \/ __// _ \/ -_)/ __// / \ \ /
/___/ \_, //_//_/\__//_//_/\__/ \__//_/ /_\_\
     /___/

* Synthetix: YFIRewards.sol
*
* Docs: https://docs.synthetix.io/
*
*
* MIT License
* ===========
*
* Copyright (c) 2020 Synthetix
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/

// File: @openzeppelin/contracts/math/SafeMath.sol

pragma solidity ^0.5.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IYFVRewards {
    function stakingPower(address account) external view returns (uint256);
}

contract YFVVote {
    using SafeMath for uint256;

    uint8 public constant MAX_VOTERS_PER_ITEM = 50;

    uint16 public constant MIN_VOTING_VALUE = 50; // 50% (x0.5 times)
    uint16 public constant MAX_VOTING_VALUE = 200; // 200% (x2 times)

    mapping(address => mapping(uint256 => uint8)) public numVoters; // poolAddress -> votingItem (periodFinish) -> numVoters (the number of voters in this round)
    mapping(address => mapping(uint256 => address[MAX_VOTERS_PER_ITEM])) public voters; // poolAddress -> votingItem (periodFinish) -> voters (array)
    mapping(address => mapping(uint256 => mapping(address => bool))) public isInTopVoters; // poolAddress -> votingItem (periodFinish) -> isInTopVoters (map: voter -> in_top (true/false))
    mapping(address => mapping(uint256 => mapping(address => uint16))) public voter2VotingValue; // poolAddress -> votingItem (periodFinish) -> voter2VotingValue (map: voter -> voting value)

    event Voted(address poolAddress, address indexed user, uint256 votingItem, uint16 votingValue);

    function isVotable(address poolAddress, address account, uint256 votingItem) public view returns (bool) {
        // already voted
        if (voter2VotingValue[poolAddress][votingItem][account] > 0) return false;

        IYFVRewards rewards = IYFVRewards(poolAddress);
        // hasn't any staking power
        if (rewards.stakingPower(account) == 0) return false;

        // number of voters is under limit still
        if (numVoters[poolAddress][votingItem] < MAX_VOTERS_PER_ITEM) return true;
        for (uint8 i = 0; i < numVoters[poolAddress][votingItem]; i++) {
            if (rewards.stakingPower(voters[poolAddress][votingItem][i]) < rewards.stakingPower(account)) return true; // there is some voters has lower staking power
        }

        return false;
    }

    function averageVotingValue(address poolAddress, uint256 votingItem) public view returns (uint16) {
        if (numVoters[poolAddress][votingItem] == 0) return 0; // no votes
        uint256 totalStakingPower = 0;
        uint256 totalWeightVotingValue = 0;
        IYFVRewards rewards = IYFVRewards(poolAddress);
        for (uint8 i = 0; i < numVoters[poolAddress][votingItem]; i++) {
            address voter = voters[poolAddress][votingItem][i];
            totalStakingPower = totalStakingPower.add(rewards.stakingPower(voter));
            totalWeightVotingValue = totalWeightVotingValue.add(rewards.stakingPower(voter).mul(voter2VotingValue[poolAddress][votingItem][voter]));
        }
        return (uint16) (totalWeightVotingValue.div(totalStakingPower));
    }

    function vote(address poolAddress, uint256 votingItem, uint16 votingValue) public {
        require(votingValue >= MIN_VOTING_VALUE, "votingValue is smaller than MIN_VOTING_VALUE");
        require(votingValue <= MAX_VOTING_VALUE, "votingValue is greater than MAX_VOTING_VALUE");
        if (!isInTopVoters[poolAddress][votingItem][msg.sender]) {
            require(isVotable(poolAddress, msg.sender, votingItem), "This account is not votable");
            uint8 voterIndex = MAX_VOTERS_PER_ITEM;
            if (numVoters[poolAddress][votingItem] < MAX_VOTERS_PER_ITEM) {
                voterIndex = numVoters[poolAddress][votingItem];
            } else {
                IYFVRewards rewards = IYFVRewards(poolAddress);
                uint256 minStakingPower = rewards.stakingPower(msg.sender);
                for (uint8 i = 0; i < numVoters[poolAddress][votingItem]; i++) {
                    if (rewards.stakingPower(voters[poolAddress][votingItem][i]) < minStakingPower) {
                        voterIndex = i;
                        minStakingPower = rewards.stakingPower(voters[poolAddress][votingItem][i]);
                    }
                }
            }
            if (voterIndex < MAX_VOTERS_PER_ITEM) {
                if (voterIndex < numVoters[poolAddress][votingItem]) {
                    isInTopVoters[poolAddress][votingItem][voters[poolAddress][votingItem][voterIndex]] = false; // remove lower power previous voter
                } else {
                    ++numVoters[poolAddress][votingItem];
                }
                isInTopVoters[poolAddress][votingItem][msg.sender] = true;
                voters[poolAddress][votingItem][voterIndex] = msg.sender;
            }
        }
        voter2VotingValue[poolAddress][votingItem][msg.sender] = votingValue;
        emit Voted(poolAddress, msg.sender, votingItem, votingValue);
    }
}
