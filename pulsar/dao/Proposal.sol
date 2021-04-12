// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./ShareSplit.sol";

contract Proposal {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    string public title;
    string public link;
    string public description;
    uint256 public startTime;
    uint256 public endTime;
    ShareSplit public shareSplit;
    uint256[] public totalVotes;

    struct VoterEntity {
        uint256 amount;
        uint256 voteItem;
        uint256 index;
    }

    mapping(address => uint256) voterAmountMap; //用户已经投票数
    address[] public voterList;

    event Voted(address voter, uint256 amount, uint256 index);

    constructor(
        address _shareSplit,
        uint256 _startTime,
        uint256 _endTime,
        string memory _title,
        string memory _link,
        string memory _description,
        uint256 _itemCount
    ) public {
        shareSplit = ShareSplit(_shareSplit);
        startTime = _startTime;
        endTime = _endTime;
        title = _title;
        link = _link;
        description = _description;
        totalVotes = new uint256[](_itemCount);
    }

    function getVoteItemCount() external view returns (uint256) {
        return totalVotes.length;
    }

    function getVoterCount() external view returns (uint256) {
        return voterList.length;
    }

    function vote(uint256 voteItem) external {
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "not in voting period"
        );    
        require(voteItem < totalVotes.length, "No such vote");

        uint256 balance = shareSplit.earnedV(msg.sender);
        require(balance > 0, "No voting rights");

        uint256 amount = balance.sub(voterAmountMap[msg.sender]);
        require(amount > 0, "No voting rights");

        if(voterAmountMap[msg.sender] > 0){
            voterList.push(msg.sender);
        }

        totalVotes[voteItem] = totalVotes[voteItem].add(amount);
        voterAmountMap[msg.sender] = balance;

        emit Voted(msg.sender, amount, voteItem);
    }

    function exist(address voter) public view returns (bool) {
        if(voterAmountMap[voter] > 0){
            return true;
        }
        return false;
    }
}
