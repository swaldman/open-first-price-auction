pragma solidity ^0.8.1;

// SPDX-License-Identifier: GPL-3.0-only

import "OpenFirstPriceAuction.sol";

abstract contract OpenFirstPriceAuctioneerUInt256 is AuctionListener {
  mapping( uint256 => OpenFirstPriceAuction ) public   keyToAuction;
  mapping( OpenFirstPriceAuction => uint256 ) public   auctionToKey;
  mapping( uint256 => OpenFirstPriceAuction[] ) public keyToPastAuctions;


  // abstract functions must be overridden by inheriting contracts
  function keyOwner( uint256 _key ) internal virtual view returns(address);

  function handleAuctionStarted( OpenFirstPriceAuction auction, address seller, uint256 key ) internal virtual;

  // Transfer ownership here!!!
  function handleAuctionCompleted( OpenFirstPriceAuction auction, address seller, address winner, uint256 key, uint256 winningBid ) internal virtual;

  function handleAuctionAborted( OpenFirstPriceAuction auction, address seller, uint256 key ) internal virtual;

  function pastAuctionCount( uint256 key ) public view returns(uint256) {
    return keyToPastAuctions[key].length;
  }

  function sell( uint256 _key, IERC20 _token, uint _reserve, uint _duration ) public {
    sell( _key, _token, _reserve, _duration, 0 );
  }
  
  function sell( uint256 _key, IERC20 _token, uint _reserve, uint _duration, uint maxAnnouncementFailures ) public {
    require( _key != 0, "The key 0 cannot be auctioned. (It has the meaning 'no key' within this auctioneer." );
    require( address(keyToAuction[_key]) == address(0), "An auction is already in progress for the specified key." );
    address currentOwner = keyOwner(_key);
    require( currentOwner == msg.sender , "You can't sell a key owned by someone else!" );
    OpenFirstPriceAuction auction = new OpenFirstPriceAuction( msg.sender, address(_token), _reserve, _duration, maxAnnouncementFailures, this );
    keyToAuction[_key] = auction;
    auctionToKey[auction] = _key;

    handleAuctionStarted( auction, msg.sender, _key );

    emit AuctionStarted( address(auction), msg.sender, _key ); 
  }

  // since concrete implementing contracts likely "freeze" keys during auctions,
  // it's important there be some way of unfreezing them if an auction fails due to announcement failures.
  function retireBrokenAuction( uint256 key ) public {
    OpenFirstPriceAuction auction = keyToAuction[key];
    require( address(auction) != address(0), "There is no auction actve for the key requested retired." );
    require( auction.announcementFailed(), "The auction in not broken; announcementFailed() has not been triggered." );

    _retireAuction( key, auction );
  }

  function auctionCompleted( address seller, address winner, uint winningBid ) public override {
    OpenFirstPriceAuction auction = OpenFirstPriceAuction(msg.sender);
    uint256 key = auctionToKey[auction];
    address oldOwner = keyOwner(key);

    require( key != 0, "Notification is not from one of our live auctions." );
    assert( oldOwner == seller );
    assert( winner != address(0) );
    assert( winner != seller );

    // we've got to ensure the is visibly over BEFORE handleAuctionCompleted,
    // so that function can safely effectuate transfers
    _retireAuction( key, auction );

    handleAuctionCompleted( auction, seller, winner, key, winningBid );

    require( keyOwner( key ) == winner, "Ownership should be transferred to the winner in handleAuctionCompleted(), has not been!" );

    emit OwnershipTransfer( seller, winner, key, winningBid );
  }

  function auctionAborted( address seller ) public override {
    OpenFirstPriceAuction auction = OpenFirstPriceAuction(msg.sender);
    uint256 key = auctionToKey[auction];
    address oldOwner = keyOwner(key);

    require( key != 0, "Notification is not from one of our live auctions." );
    assert( oldOwner == seller );

    _retireAuction( key, auction );

    handleAuctionAborted( auction, seller, key );

    emit OwnershipRetained( seller, key );
  }

  function _retireAuction( uint256 key, OpenFirstPriceAuction auction ) internal {
    keyToPastAuctions[key].push(auction);
    keyToAuction[key] = OpenFirstPriceAuction(address(0));
    auctionToKey[auction] = 0;

  }

  event AuctionStarted( address indexed auction, address indexed seller, uint256 key );
  event OwnershipClaimed( address indexed claimant, uint256 key );
  event OwnershipRetained( address indexed seller, uint256 key );
  event OwnershipTransfer( address indexed seller, address indexed buyer, uint256 key, uint price );
}
