// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./PreProtonToken.sol";
import "./interfaces/INFTProxy.sol";

contract ProtonRedeemNFT is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // Burn address
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    PreProtonToken public preproton;
    address public protonAddress;

    uint256 public startBlock;

    bool public hasBurnedUnsoldPresale = false;

    uint256 public tier1Amount = 3000 ether;
    uint256 public tier2Amount = 9000 ether;
    uint256 public tier3Amount = 16000 ether;

    INFTProxy public nftproxy;
    bool private _isNftProxySetup = false;

    // Keeps track of all the already airdropped addresses
    address[] private airdroppedAddresses;
    // Keeps track of all the addresses added to airdroppedAddresses
    mapping (address => bool) public airdroppedWallets;


    event protonSwap(address sender, uint256 amount);
    event burnUnclaimedProto(uint256 amount);
    event startBlockChanged(uint256 newStartBlock);
    event airdroppedNFT(address sender, uint256 amount, uint8 tier);

    constructor(uint256 _startBlock, address _preprotonAddress, address _protonAddress) public {
        require(_preprotonAddress != _protonAddress, "preproton cannot be equal to proton");
        startBlock   = _startBlock;
        preproton = PreProtonToken(_preprotonAddress);
        protonAddress  = _protonAddress;
    }

    function getNFTAirdroppedAddresses() external view onlyOwner returns(address[] memory){
        return airdroppedAddresses;
    }

    function setNFTProxy(INFTProxy _nftproxy) external onlyOwner {
        nftproxy = _nftproxy;
        _isNftProxySetup = true;
    }

    function swapPreProtonForProton(uint256 swapAmount) external nonReentrant {
        require(block.number >= startBlock, "proton redemption hasn't started yet, good things come to those that wait ;)");
        require(IERC20(protonAddress).balanceOf(address(this)) >= swapAmount, "Not Enough tokens in contract for swap");
        preproton.transferFrom(msg.sender, BURN_ADDRESS, swapAmount);
        IERC20(protonAddress).transfer(msg.sender, swapAmount);

        if (_isNftProxySetup && (airdroppedWallets[msg.sender] == false)
                && swapAmount >= tier1Amount) {
            
            uint8 tier = 0;
            if(swapAmount >= tier3Amount){
                // Airdrop tier 3 NFT
                tier = 3;
                nftproxy.mintTo(msg.sender, tier);
            } else if(swapAmount >= tier2Amount) {
                // Airdrop tier 2 NFT
                tier = 2;
                nftproxy.mintTo(msg.sender, tier);
            } else {
                // Airdrop tier 1 NFT
                tier = 1;
                nftproxy.mintTo(msg.sender, tier);
            }

            // Add holder to historical holders
            airdroppedAddresses.push(msg.sender);
            airdroppedWallets[msg.sender] = true;
            emit airdroppedNFT(msg.sender, swapAmount, tier);
        }

        emit protonSwap(msg.sender, swapAmount);
    }

    function sendUnclaimedProtoToDeadAddress() external onlyOwner {
        require(block.number > preproton.endBlock(), "can only send excess proton to dead address after presale has ended");
        require(!hasBurnedUnsoldPresale, "can only burn unsold presale once!");

        require(preproton.pprotonRemaining() <= IERC20(protonAddress).balanceOf(address(this)),
            "burning too much proton, founders may need to top up");

        if (preproton.pprotonRemaining() > 0)
            IERC20(protonAddress).transfer(BURN_ADDRESS, preproton.pprotonRemaining());
        hasBurnedUnsoldPresale = true;

        emit burnUnclaimedProto(preproton.pprotonRemaining());
    }

    function setStartBlock(uint256 _newStartBlock) external onlyOwner {
        require(block.number < startBlock, "cannot change start block if sale has already commenced");
        require(block.number < _newStartBlock, "cannot set start block in the past");
        startBlock = _newStartBlock;

        emit startBlockChanged(_newStartBlock);
    }
}