// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CrowdFund{

    event Launch(uint id, address indexed creator, uint goal, uint32 startAt, uint32 endAt);
    event Cancel(uint id);
    event Pledge(uint indexed id, address indexed caller, uint amount);
    event Unpledge(uint indexed id, address indexed caller, uint amount);
    event Claim(uint id);
    event Refund(uint id, address indexed caller, uint amount);

  struct Campaign {
        address creator;
        uint goal;
        uint pledged;
        uint32 startAt;
        uint32 endAt;
        bool claimed;
    }

     IERC20 public token; //last versions we dont need to use immutable
     uint public count;
     mapping(uint => Campaign) public campaigns;
     mapping(uint => mapping(address => uint)) public pledgedAmount;

      constructor(address _token) {
        token = IERC20(_token);

    }

    function launch(uint _goal, uint32 _startAt, uint32 _endAt) external {
        require(_startAt >= block.timestamp,"Start time  < Block Timestamp");
        require(_endAt >= _startAt,"Endtime < start time");
        require(_endAt <= block.timestamp + 90 days, "End time > 90 days");

         count += 1;
         campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });

    }

    function cancel(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(msg.sender == campaign.creator, "You are not creator");
        require(block.timestamp < campaign.startAt, "Already started");

        delete campaigns[_id];
        emit Cancel(_id);
    }

    function pledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt, "Not Started yet");
        require(block.timestamp <= campaign.endAt, "Ended");

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        emit Pledge(_id, msg.sender, _amount);
    }

    function unPledge(uint _id,uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAt, "Ended");
        require(block.timestamp >= campaign.startAt, "Not started yet");
        require(pledgedAmount[_id][msg.sender] >= _amount,"Not Enough Tokens");

        campaign.pledged -= _amount;
        pledgedAmount[_id][msg.sender] -= _amount;
        token.transfer(msg.sender, _amount);

        emit Unpledge(_id, msg.sender, _amount);
    }

    function claim(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(msg.sender == campaign.creator, "You are not creator");
        require(block.timestamp > campaign.endAt, "Not ended");
        require(campaign.pledged >= campaign.goal, "pledge < goal");
        require(!campaign.claimed, "Already claimed");

        campaign.claimed = true;
        token.transfer(campaign.creator, campaign.pledged);

        emit Claim(_id);
    }

    function refund(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt, "not ended");
        require(campaign.pledged < campaign.goal, "pledge < goal");

        uint bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0; //order important because reentrancy attack
        token.transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }

} 
