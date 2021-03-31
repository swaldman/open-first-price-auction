package com.mchange.sc.v1.auction.firstprice.contract;

import org.specs2._
import Testing._

import com.mchange.sc.v1.consuela.ethereum.specification.Denominations._
import com.mchange.sc.v1.consuela.ethereum.stub
import com.mchange.sc.v1.consuela.ethereum.stub.sol

class EthTestAuctioneerSpec extends Specification with AutoSender { def is = sequential ^ s2"""
  A TestAuctioneer using ETH as numeraire...
     there should be no auction initially associated with a key                                                    ${e00}
     should be able to sell a key, creating an auction using ETH as the numeraire.                                 ${e10}
     the seller of the new key should have become its initial owner                                                ${e20}
     another sender should not be able to sell the same key                                                        ${e30}
     that other sender should not be able to bid on the key below its reserve                                      ${e40}
     that other sender should be able to bid on the key above its reserve                                          ${e50}
     that other sender should now be the current bidder, at its last bid                                           ${e60}
     a new bidder should be able to outbid the prior bidder, and that bid should become current.                   ${e70}
     the ETH balance of the auction contract should be the sum of both (exactly funded) bids.                      ${e75}
     the first bidder should be able to withdraw her bid and get it back                                           ${e80}
     the first bidder should have no holdings, the second bidder her bid                                           ${e90}
     the first bidder submitting a new but lower bid should fail                                                   ${e100}
     the first bidder submitting a new but higher bid paying excess ETH should succeed and update holdings.        ${e110}
     the ETH balance of the auction contract should be the sum of the two bids and the excess.                     ${e115}
     the now highest bidder can withdraw her excess.                                                               ${e120}
     the seller should not be able to claim proceeds (yet).                                                        ${e130}
     the ETH auction should not yet be done                                                                        ${e140}
     after a minute (and a block), the ETH auction should be done.                                                 ${e150}
     nonsellers should not be allowed to claim proceeds.                                                           ${e160}
     seller should now be allowed to claim proceeds, yielding the correct balance increment and buyer holdings.    ${e170}
     non-winning bidder holdings are correct and constitute the full contract ETH balance.                         ${e180}
     auction can be announced, yielding a transfer of ownership to winning bidder.                                 ${e190}
     losing bidder can still withdraw its bid, leaving a zero contract balance.                                    ${e200}
  """

  /*
   * 
   * This is set-up via `Test / ethcfgAutoDeployContracts` in build.sbt
   * 
   */ 
  val testAuctioneer = TestAuctioneer( TestSender(0).contractAddress(0) )

  def fundedRandomSender() : stub.Sender.Signing = { // yuk
    import scala.concurrent.Await
    import scala.concurrent.duration._

    val out = createRandomSender()
    Await.ready( Faucet.sendWei( out.address, sol.UInt256(1.ether) ), Duration.Inf )
    out
  }

  val sender = (0 until 3).map( _ => fundedRandomSender())

  val firstKey = "firstKey"

  def e00 = {
    testAuctioneer.view.keyToAuction( firstKey ) == sol.Address.Zero
  }
  def e10 = {
    testAuctioneer.txn.sell( firstKey, sol.Address.Zero, sol.UInt256(0.02 ether), sol.UInt256(60) )( sender(0) )
    testAuctioneer.view.keyToAuction( firstKey ) != sol.Address.Zero
  }
  def e20 = {
    testAuctioneer.view.keyToAuction( firstKey ) != sender(0).address
  }
  def e30 = {
    try {
      testAuctioneer.txn.sell( firstKey, sol.Address.Zero, sol.UInt256(0.02 ether), sol.UInt256(60) )( sender(1) )
      false
    }
    catch {
      case _ : Exception => true
    }
  }
  def e40 = {
    try {
      val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
      auction.txn.bid( sol.UInt256(0.01 ether), stub.Payment.ofWei(sol.UInt256(0.01 ether)) )( sender(1) )
      false
    }
    catch {
      case _ : Exception => true
    }
  }
  def e50 = {
    try {
      val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
      auction.txn.bid( sol.UInt256(0.03 ether), stub.Payment.ofWei(sol.UInt256(0.03 ether)) )( sender(1) )
      true
    }
    catch {
      case _ : Exception => false
    }
  }
  def e60 = {
    val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
    auction.view.current_bidder() == sender(1).address && auction.view.current_bid() == sol.UInt256(0.03 ether)
  }
  def e70 = {
    val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
    auction.txn.bid( sol.UInt256(0.04 ether), stub.Payment.ofWei(sol.UInt256(0.04 ether)) )( sender(2) )
    auction.view.current_bidder() == sender(2).address && auction.view.current_bid() == sol.UInt256(0.04 ether)
  }
  def e75 = {
    awaitBalance(testAuctioneer.view.keyToAuction( firstKey )) == 0.07.ether
  }
  def e80 = {
    val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
    val initialBalance = sender(1).awaitBalance()
    auction.txn.withdraw()( sender(1) )
    val endBalance = sender(1).awaitBalance()
    // println( s"initialBalance: ${initialBalance}; endBalance: ${endBalance}" )
    endBalance > initialBalance + (9 * 0.03 ether) / 10 && endBalance < initialBalance + (11 * 0.03 ether) / 10 // a bit of play for gas costs
  }
  def e90 = {
    val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
    (auction.view.holdings(sender(2).address).widen == 0.04.ether) && (auction.view.holdings(sender(1).address).widen == 0)
  }
  def e100 = {
    try {
      val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
      auction.txn.bid( sol.UInt256(0.03 ether), stub.Payment.ofWei(sol.UInt256(0.03 ether)) )( sender(1) )
      false
    }
    catch {
      case _ : Exception => true
    }
  }
  def e110 = {
    val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
    auction.txn.bid( sol.UInt256(0.05 ether), stub.Payment.ofWei(sol.UInt256(0.10 ether)) )( sender(1) )
    auction.view.current_bidder() == sender(1).address && auction.view.current_bid() == sol.UInt256(0.05 ether) && auction.view.holdings(sender(1).address).widen == 0.1.ether
  }
  def e115 = {
    awaitBalance(testAuctioneer.view.keyToAuction( firstKey )) == 0.14.ether
  }
  def e120 = {
    val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
    val initialBalance = sender(1).awaitBalance()
    auction.txn.withdraw()( sender(1) )
    val endBalance = sender(1).awaitBalance()
    // println( s"initialBalance: ${initialBalance}; endBalance: ${endBalance}" )
    endBalance > initialBalance + (9 * 0.05 ether) / 10 && endBalance < initialBalance + (11 * 0.05 ether) / 10 // a bit of play for gas costs
  }

  private def tryClaimProceeds( s : stub.Sender.Signing ) : Boolean = {
    try {
      val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
      auction.txn.claimProceeds()( s )
      true
    }
    catch {
      case e : Exception => false
    }
  }

  def e130 = !tryClaimProceeds( sender(0) )

  def e140 = {
    val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
    !auction.view.isDone()
  }
  def e150 = {
    println("Sleeping 60 seconds...")
    Thread.sleep(60000)
    val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))

    // force a block, since ganache produces them lazily
    auction.txn.isDone()

    auction.view.isDone()
  }
  def e160 = {
    val sender1 = tryClaimProceeds( sender(1) )
    val sender2 = tryClaimProceeds( sender(2) )
    !(sender1 || sender2)
  }
  def e170 = {
    val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
    val initialBalance = sender(0).awaitBalance()
    val check = tryClaimProceeds( sender(0) )
    val endBalance = sender(0).awaitBalance()
    // println( s"initialBalance: ${initialBalance}; endBalance: ${endBalance}" )
    check && endBalance > initialBalance + (9 * 0.05 ether) / 10 && endBalance < initialBalance + (11 * 0.05 ether) / 10 && auction.view.holdings( sender(1).address ).widen == 0 // a bit of play for gas costs
  }
  def e180 = {
    val auctionAddress = testAuctioneer.view.keyToAuction( firstKey )
    val auction = OpenFirstPriceAuction(auctionAddress)
    auction.view.holdings( sender(2).address ).widen == 0.04.ether && awaitBalance( auctionAddress ) == 0.04.ether
  }
  def e190 = {
    val auction = OpenFirstPriceAuction(testAuctioneer.view.keyToAuction( firstKey ))
    auction.txn.announce()( sender(1) )
    testAuctioneer.view.keyToOwner( firstKey ) == sender(1).address
  }
  def e200 = {
    val numPastAuctions = testAuctioneer.view.pastAuctionCount(firstKey).widen;
    val lastAuction = OpenFirstPriceAuction(testAuctioneer.view.keyToPastAuctions( firstKey, sol.UInt256(numPastAuctions - 1 )))
    val initialBalance = sender(2).awaitBalance()
    lastAuction.txn.withdraw()( sender(2) )
    val endBalance = sender(2).awaitBalance()
    // println( s"initialBalance: ${initialBalance}; endBalance: ${endBalance}" )
    endBalance > initialBalance + (9 * 0.04 ether) / 10 && endBalance < initialBalance + (11 * 0.04.ether) / 10 && lastAuction.view.holdings( sender(2).address ).widen == 0 && awaitBalance( lastAuction.address ) == 0 // a bit of play for gas costs
  }
}


