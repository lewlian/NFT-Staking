// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "hardhat/console.sol";

contract NFTeeStaker is ERC20 {

  // Stake one or more NFTs

  // Evert 24 hours, they should be getting 1000 tokens - prorated for smaller times

  // Unstake

  // Claim those tokens

  // ----

  // NFTee Contract
  // struct Staker
  IERC721 nftContract;

  uint256 private constant SECONDS_PER_DAY = 24 * 60 * 60;
  uint256 private constant BASE_YIELD_RATE = 1000 ether; // means a 1000 token

  struct Staker{
    // X number of tokens every 24 hours
    uint256 currYield;
    // how many tokens have the accumulated and not claimed
    uint256 rewards;
    // last time that rewards were calculated
    uint256 lastCheckpoint;

  }

  mapping(address => Staker) public stakers;
  mapping(uint256 => address) public tokenOwners;

  constructor(address _nftContract, string memory name, string memory symbol) ERC20(name, symbol) {
    nftContract = IERC721(_nftContract);
  }

  function stake(uint256[] memory tokenIds) public {
    Staker storage user = stakers[msg.sender];
    uint256 yield = user.currYield;

    uint256 length = tokenIds.length;

    for (uint256 i = 0; i< length; i++){
      require(nftContract.ownerOf(tokenIds[i]) == msg.sender, "NOT_OWNED");

      nftContract.safeTransferFrom(msg.sender, address(this),tokenIds[i]);
      tokenOwners[tokenIds[i]] = msg.sender;

      yield += BASE_YIELD_RATE;
    }
    accumulate(msg.sender);

    user.currYield = yield;
  }

  function unstake(uint256[] memory tokenIds) public {
    Staker storage user = stakers[msg.sender];
    uint256 yield = user.currYield;

    uint256 length = tokenIds.length;
    for (uint256 i=0; i<length;i++) {
      require(tokenOwners[tokenIds[i]]==msg.sender, "NOT_ORIGINAL_OWNER");
      require(nftContract.ownerOf(tokenIds[i]) == address(this), "NOT STAKED");

      tokenOwners[tokenIds[i]] = address(0);
      if(yield != 0) {
        yield -= BASE_YIELD_RATE;
      }

      nftContract.safeTransferFrom(address(this), msg.sender, tokenIds[i]);
    }
    accumulate(msg.sender);
    user.currYield = yield;

  }

  function claim() public {
    Staker storage user = stakers[msg.sender];
    accumulate(msg.sender);

    _mint(msg.sender, user.rewards);
    user.rewards = 0; 

  }

  function accumulate(address staker) internal {
    stakers[staker].rewards += getRewards(staker);
    stakers[staker].lastCheckpoint = block.timestamp;
  }

  function getRewards(address staker) public view returns (uint256) {
    Staker memory user = stakers[staker];

    if (user.lastCheckpoint == 0) {
      return 0;
    }

    return ((block.timestamp - user.lastCheckpoint) * user.currYield) / SECONDS_PER_DAY;
  }

  function onERC721Received(
    address,address,uint256,bytes calldata
  ) external pure returns (bytes4) {
    return bytes4(
      keccak256("onERC721Received(address,address,uint256,bytes)") 
    );
  }
}
