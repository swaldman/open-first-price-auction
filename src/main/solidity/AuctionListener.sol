pragma solidity ^0.8.1;

// SPDX-License-Identifier: GPL-3.0-only

interface AuctionListener {
  function auctionCompleted( address seller, address winner, uint winningBid ) external;
  function auctionAborted( address seller ) external;
}
