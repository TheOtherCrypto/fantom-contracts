// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ERC20.sol";

// PreProtonToken
contract PreProtonToken is ERC20('PRE-PROTON', 'PPROTON'), ReentrancyGuard {

    address public constant feeAddress = 0x8a347ec3cB809D9a53d2B8d74e23f08d908e19dc;

    // Number of Proto released per FTM, times 10**35
    uint256 public salePriceE35 = 10 * (10 ** 35); // 1 ftm == 10 PROTO

    // 1M proton presale
    uint256 public constant pprotonMaximumSupply = 1000 * (10 ** 3) * (10 ** 18); // 1M pproton

    // We use a counter to defend against people sending pproton back
    uint256 public pprotonRemaining = pprotonMaximumSupply;

    // Max 30k Proton-per-investor during the presale (3k FTM)
    uint256 public constant maxPprotonPurchase = 30 * (10 ** 3) * (10 ** 18); //30k pproton

    uint256 oneHourFtm = 4000; // 0.9 secs per block, 3600/0.9=4000
    uint256 oneDayFtm = oneHourFtm * 24;
    uint256 threeDaysFtm = oneDayFtm * 3;

    uint256 public startBlock;
    uint256 public endBlock;

    mapping(address => uint256) public userPprotonTally;

    event pprotonPurchased(address sender, uint256 ftmSpent, uint256 pprotonReceived);
    event startBlockChanged(uint256 newStartBlock, uint256 newEndBlock);
    event salePriceE35Changed(uint256 newSalePriceE5);

    constructor(uint256 _startBlock) public {
        startBlock = _startBlock;
        endBlock   = _startBlock + threeDaysFtm;
        _mint(address(this), pprotonMaximumSupply);
    }

    function buyPproton() external payable nonReentrant {
        require(block.number >= startBlock, "presale hasn't started yet, good things come to those that wait");
        require(block.number < endBlock, "presale has ended, come back next time!");
        require(pprotonRemaining > 0, "No more pproton remaining! Come back next time!");
        require(IERC20(address(this)).balanceOf(address(this)) > 0, "No more pproton left! Come back next time!");
        require(msg.value > 0, "not enough ftm provided");
        require(msg.value <= 3000e18, "too much ftm provided");
        require(userPprotonTally[msg.sender] < maxPprotonPurchase, "user has already purchased too much pproton");

        uint256 originalPprotonAmount = (msg.value * salePriceE35) / 1e35;

        uint256 pprotonPurchaseAmount = originalPprotonAmount;

        if (pprotonPurchaseAmount > maxPprotonPurchase)
            pprotonPurchaseAmount = maxPprotonPurchase;

        if ((userPprotonTally[msg.sender] + pprotonPurchaseAmount) > maxPprotonPurchase)
            pprotonPurchaseAmount = maxPprotonPurchase - userPprotonTally[msg.sender];

        // if we dont have enough left, give them the rest.
        if (pprotonRemaining < pprotonPurchaseAmount)
            pprotonPurchaseAmount = pprotonRemaining;

        require(pprotonPurchaseAmount > 0, "user cannot purchase 0 pproton");

        // shouldn't be possible to fail these asserts.
        assert(pprotonPurchaseAmount <= pprotonRemaining);
        assert(pprotonPurchaseAmount <= IERC20(address(this)).balanceOf(address(this)));
        IERC20(address(this)).transfer(msg.sender, pprotonPurchaseAmount);
        pprotonRemaining = pprotonRemaining - pprotonPurchaseAmount;
        userPprotonTally[msg.sender] = userPprotonTally[msg.sender] + pprotonPurchaseAmount;

        uint256 ftmSpent = msg.value;
        uint256 refundAmount = 0;
        if (pprotonPurchaseAmount < originalPprotonAmount) {
            // max pprotonPurchaseAmount = 6e20, max msg.value approx 3e22 (if 10c ftm, worst case).
            // overfow check: 6e20 * 3e22 * 1e24 = 1.8e67 < type(uint256).max
            // Rounding errors by integer division, reduce magnitude of end result.
            // We accept any rounding error (tiny) as a reduction in PAYMENT, not refund.
            ftmSpent = ((pprotonPurchaseAmount * msg.value * 1e24) / originalPprotonAmount) / 1e24;
            refundAmount = msg.value - ftmSpent;
        }
        if (ftmSpent > 0) {
            (bool success, bytes memory returnData) = payable(address(feeAddress)).call{value: ftmSpent}("");
            require(success, "failed to send ftm to fee address");
        }
        if (refundAmount > 0) {
            (bool success, bytes memory returnData) = payable(msg.sender).call{value: refundAmount}("");
            require(success, "failed to send ftm to customer address");
        }

        emit pprotonPurchased(msg.sender, ftmSpent, pprotonPurchaseAmount);
    }

    function setStartBlock(uint256 _newStartBlock) external onlyOwner {
        require(block.number < startBlock, "cannot change start block if sale has already commenced");
        require(block.number < _newStartBlock, "cannot set start block in the past");
        startBlock = _newStartBlock;
        endBlock   = _newStartBlock + threeDaysFtm;

        emit startBlockChanged(_newStartBlock, endBlock);
    }

    function setSalePriceE35(uint256 _newSalePriceE35) external onlyOwner {
        require(block.number < startBlock - (oneHourFtm * 4), "cannot change price 4 hours before start block");
        require(_newSalePriceE35 >= 5 * (10 ** 35), "new price can't too low");
        require(_newSalePriceE35 <= 15 * (10 ** 35), "new price can't too high");
        salePriceE35 = _newSalePriceE35;

        emit salePriceE35Changed(salePriceE35);
    }
}