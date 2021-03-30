pragma solidity ^0.8.1;

import "../../main/solidity/OpenFirstPriceAuction.sol";

contract TestAuctioneer is AuctionListener {
  mapping( string => OpenFirstPriceAuction ) keyToAuction;
  mapping( OpenFirstPriceAuction => string)  auctionToKey;
  mapping( string => address )               keyToOwner;

  function sell( string calldata _key, IERC20 _token, uint _reserve, uint _duration ) public {
    require( nonemptyString(_key), "The empty string cannot be auctioned. (It has the meaning 'no key' within this auctioneer." );
    require( address(keyToAuction[_key]) == address(0), "An auction is already in progress for the specified key." );
    address currentOwner = keyToOwner[_key];
    bool newClaim = currentOwner == address(0);
    require( newClaim || currentOwner == msg.sender , "You can't sell a key owned by someone else!" );
    OpenFirstPriceAuction auction = new OpenFirstPriceAuction( msg.sender, address(_token), _reserve, _duration, this );
    keyToAuction[_key] = auction;
    auctionToKey[auction] = _key;
    
    if ( newClaim ) {
      keyToOwner[_key] = msg.sender;
      emit OwnershipClaimed( currentOwner, _key );
    }
  }

  function auctionCompleted( address seller, address winner, uint winningBid ) public override {
    OpenFirstPriceAuction auction = OpenFirstPriceAuction(msg.sender);
    string memory key = auctionToKey[auction];
    address oldOwner = keyToOwner[key];

    require( nonemptyString(key), "Notification is not from one of our live auctions." );
    assert( oldOwner == seller );
    assert( winner != address(0) );
    assert( winner != seller );
    
    keyToOwner[key] = winner;

    keyToAuction[key] = OpenFirstPriceAuction(address(0));
    auctionToKey[auction] = "";

    emit OwnershipTransfer( seller, winner, key, winningBid );
  }

  function auctionAborted( address seller ) public override {
    OpenFirstPriceAuction auction = OpenFirstPriceAuction(msg.sender);
    string memory key = auctionToKey[auction];
    address oldOwner = keyToOwner[key];


    require( nonemptyString(key), "Notification is not from one of our live auctions." );
    assert( oldOwner == seller );

    keyToAuction[key] = OpenFirstPriceAuction(address(0));
    auctionToKey[auction] = "";

    emit OwnershipRetained( seller, key );
  }

  function nonemptyString( string memory s ) pure private returns (bool) {
    return bytes(s).length > 0;
  }

  event OwnershipClaimed( address indexed claimant, string key );
  event OwnershipRetained( address indexed seller, string key );
  event OwnershipTransfer( address indexed seller, address indexed buyer, string key, uint price );
}
