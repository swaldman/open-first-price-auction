pragma solidity ^0.8.1;

import "../../main/solidity/OpenFirstPriceAuctioneer.sol";

contract TestAuctioneer is OpenFirstPriceAuctioneerUInt256 {
  mapping( uint256 => address ) public keyToOwner;

  function claim( uint256 key ) public {
    address currentOwner = keyToOwner[key];
    require( currentOwner == address(0) || currentOwner == msg.sender, "Cannot claim a key already owned by someone else." );
    keyToOwner[key] = msg.sender;
  }

  function owner( uint256 _key ) internal override view returns(address) {
    return keyToOwner[_key];
  }

  function handleAuctionStarted( OpenFirstPriceAuction /*auction*/, address /*seller*/, uint256 /*key*/ ) internal override {}

  function handleAuctionCompleted( OpenFirstPriceAuction /*auction*/, address /*seller*/, address winner, uint256 key, uint256 /*winningBid*/ ) internal override {
    keyToOwner[key] = winner;
  }

  function handleAuctionAborted( OpenFirstPriceAuction /*auction*/, address /*seller*/, uint256 /*key*/ ) internal override {}
}
