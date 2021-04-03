pragma solidity ^0.8.1;

// SPDX-License-Identifier: GPL-3.0-only

import "OpenFirstPriceAuction.sol";

abstract contract OpenFirstPriceAuctioneerUInt256 is AuctionListener {
  mapping( uint256 => OpenFirstPriceAuction ) public   keyToAuction;
  mapping( OpenFirstPriceAuction => uint256 ) public   auctionToKey;
  mapping( uint256 => OpenFirstPriceAuction[] ) public keyToPastAuctions;

  function keyToOwner( uint256 _key ) internal virtual returns(address);

  function handleAuctionStarted( OpenFirstPriceAuction auction, address seller, uint256 key ) internal virtual;

  // Transfer ownership here!!!
  function handleAuctionCompleted( OpenFirstPriceAuction auction, address seller, address winner, uint256 key, uint256 winningBid ) internal virtual;

  function handleAuctionAborted( OpenFirstPriceAuction auction, address seller, uint256 key ) internal virtual;

  function pastAuctionCount( uint256 key ) public view returns(uint256) {
    return keyToPastAuctions[key].length;
  }

  function sell( uint256 _key, IERC20 _token, uint _reserve, uint _duration ) public {
    require( _key != 0, "The key 0 cannot be auctioned. (It has the meaning 'no key' within this auctioneer." );
    require( address(keyToAuction[_key]) == address(0), "An auction is already in progress for the specified key." );
    address currentOwner = keyToOwner(_key);
    require( currentOwner == msg.sender , "You can't sell a key owned by someone else!" );
    OpenFirstPriceAuction auction = new OpenFirstPriceAuction( msg.sender, address(_token), _reserve, _duration, this );
    keyToAuction[_key] = auction;
    auctionToKey[auction] = _key;

    handleAuctionStarted( auction, msg.sender, _key );

    emit AuctionStarted( address(auction), msg.sender, _key ); 
  }

  function auctionCompleted( address seller, address winner, uint winningBid ) public override {
    OpenFirstPriceAuction auction = OpenFirstPriceAuction(msg.sender);
    uint256 key = auctionToKey[auction];
    address oldOwner = keyToOwner(key);

    require( key != 0, "Notification is not from one of our live auctions." );
    assert( oldOwner == seller );
    assert( winner != address(0) );
    assert( winner != seller );
    
    keyToPastAuctions[key].push(auction);
    keyToAuction[key] = OpenFirstPriceAuction(address(0));
    auctionToKey[auction] = 0;

    handleAuctionCompleted( auction, seller, winner, key, winningBid );

    emit OwnershipTransfer( seller, winner, key, winningBid );
  }

  function auctionAborted( address seller ) public override {
    OpenFirstPriceAuction auction = OpenFirstPriceAuction(msg.sender);
    uint256 key = auctionToKey[auction];
    address oldOwner = keyToOwner(key);

    require( key != 0, "Notification is not from one of our live auctions." );
    assert( oldOwner == seller );

    keyToPastAuctions[key].push(auction);
    keyToAuction[key] = OpenFirstPriceAuction(address(0));
    auctionToKey[auction] = 0;

    handleAuctionAborted( auction, seller, key );

    emit OwnershipRetained( seller, key );
  }

  event AuctionStarted( address indexed auction, address indexed seller, uint256 key );
  event OwnershipClaimed( address indexed claimant, uint256 key );
  event OwnershipRetained( address indexed seller, uint256 key );
  event OwnershipTransfer( address indexed seller, address indexed buyer, uint256 key, uint price );
}
