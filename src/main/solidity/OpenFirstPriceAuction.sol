pragma solidity ^0.8.1;

// SPDX-License-Identifier: GPL-3.0-only

import "AuctionListener.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract OpenFirstPriceAuction {
  address public seller;
  
  IERC20  public token;
  uint    public reserve;
  
  uint    public current_bid;
  address public current_bidder;

  bool public announced = false;
  bool public claimed   = false;

  uint public end_time;

  mapping( address => uint ) public holdings;

  AuctionListener listener;

  constructor( address _seller, address _token, uint _reserve, uint _duration, AuctionListener _listener ) {
    seller      = _seller;
    token       =  IERC20(_token);
    reserve     = _reserve;
    current_bid = _reserve - 1;
    end_time    =  block.timestamp + _duration;
    listener    = _listener;
  }

  modifier live {
    require( block.timestamp <= end_time, "The auction has ended.");
    _;
  }

  modifier done {
    require( block.timestamp > end_time, "The auction has ended.");
    _;
  }

  function isDone() public view returns (bool) {
    return block.timestamp > end_time;
  }

  function isLive() public view returns (bool) {
    return !isDone();
  }

  function secondsRemaining() public view returns (uint) {
    if ( end_time > block.timestamp ) {
      return end_time - block.timestamp;
    }
    else {
      return 0;
    }
  }

  function bid( uint atoms ) public live payable {
    require( atoms >= reserve, "Bid does not meet the reserve price." );
    require( atoms >= current_bid, "Bid is no higher than the current leading bid." );
    require( msg.sender != seller, "Seller address is forbidden from bidding." );
    current_bid = atoms;
    current_bidder = msg.sender;
    _accept( atoms );
  }

  function claimProceeds() public done {
    require(!claimed, "The auction proceeds can be claimed only once!");
    require( msg.sender == seller, "Only the seller may call claimProceeds(), and only after the auction is done." );
    _claimProceeds();
  }

  function announce() public done {
    require(!announced, "The auction result can be announced only once!");
    require(address(listener) != address(0), "This auction has no listener to announce to.");
    announced = true;
    listener.auctionCompleted( address(this), seller, current_bidder, current_bid );
    emit AuctionAnnounced( seller, current_bidder, current_bid );
  }

  // withdrawals can be made at any time
  function withdraw() public { 
    require( msg.sender != seller, "The seller must call claimProceeds(), only after the auction is done." );
    uint excess;
    if (msg.sender == current_bidder) {
      excess = holdings[msg.sender] - current_bid;
    }
    else {
      excess = holdings[msg.sender];
    }
    _withdrawToTransactor( excess );
  }

  function _usesEth() internal view returns (bool usesEth) {
    usesEth = (address(token) == address(0));
  }

  function _claimProceeds() internal done {
    require(!claimed, "The proceeds of this auction have already been claimed.");
    claimed = true;
    holdings[current_bidder] = holdings[current_bidder] - current_bid;
    if (_usesEth()) {
      (bool success, ) = seller.call{value: current_bid}("");
      require(success, "Disbursal of ETH to seller failed!");      
    }
    else {
      require( token.transferFrom( address(this), seller, current_bid ), "Disbursal of tokens to seller failed!" );
    }
    emit ProceedsClaimed( current_bid );
  }

  function _withdrawToTransactor( uint atoms ) internal {
    require( atoms > 0, "Cannot withdraw zero tokens." );
    holdings[msg.sender] = holdings[msg.sender] - atoms;
    if (_usesEth()) {
      (bool success, ) = msg.sender.call{value: atoms}("");
      require(success, "Withdrawal of ETH failed!");      
    }
    else {
      require( token.transferFrom( address(this), msg.sender, atoms ), "Witdrawal of tokens failed!" );
    }
    emit FundsWithdrawn( msg.sender, atoms );
  }

  function _accept( uint bidAtoms ) internal {
    if (_usesEth()) {
      uint totalFunds = holdings[msg.sender] + msg.value;
      require(totalFunds >= bidAtoms, "User failed to send the ETH required for bid.");
      holdings[msg.sender] = totalFunds;
      emit BidAccepted( msg.sender, bidAtoms, totalFunds );
    }
    else {
      uint currentFunds = holdings[msg.sender];
      require( bidAtoms > currentFunds, "Won't accept an ERC20 bid that must be less than or equal to a prior bid." );
      uint fundsNeeded = bidAtoms - currentFunds;
      holdings[msg.sender] = currentFunds + fundsNeeded;
      require( token.transferFrom( msg.sender, address(this), fundsNeeded ), "Transfer of bidder's tokens to auction contract failed." );
      emit BidAccepted( msg.sender, bidAtoms, bidAtoms );
    }
  }

  event BidAccepted( address indexed bidder, uint bidAmount, uint bidderBalance );
  event FundsWithdrawn( address indexed bidder, uint amountWithdrawn );
  event ProceedsClaimed( uint amountClaimed );
  event AuctionAnnounced( address indexed seller, address indexed winner, uint winningBid );
}
