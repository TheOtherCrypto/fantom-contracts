// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract ProtofiNFT is ERC721Enumerable, Whitelistable {
    using Strings for uint256;
    using SafeMath for uint256;

    struct Protofi { 
        uint256 id;
        uint8 tier;
        bool used;
    }
 
    mapping(uint256 => Protofi) public nfts;

    bool public pause = true;

    uint256 public tokenCounter;
    uint256 public maxMintAmount = 10;
    // FTM MINTING
    uint256 public costFtm = 0.05 ether;
    uint256 public maxcostFtm = 0.1 ether;
    uint256 public splitFtmDev = 20;
    // TOKEN MINTING
    uint256 public costToken = 0.05 ether;
    uint256 public maxcostToken = 0.1 ether;
    uint256 public splitTokenDev = 5;
    // RARITY INDEX
    uint8[5] public baseRange = [30,25,20,15,10];
    uint8[5] public maxbonusRange = [10,15,20,25,30];

    address public dev1;
    address public dev2;
    address public marketing;

    string public uri;
    string[5] tiersName = ["Common","Rare","Epic","Legendary","Mythic"];
    string[5] tiersDesc = ["Common","Rare","Epic","Legendary","Mythic"];

    ERC20 public token;

    // Event NFT
    event CreatedNFT(uint256 indexed _tokenId, uint8 _tier);
    event UsedNFT(uint256 indexed _tokenId, address _nftOwner);
    // Event Receiver
    event ChangedToken(address _split);
    event ChangedSplitFtm(uint256 _split);
    event ChangedSplitToken(uint256 _split);    
    event ChangedCostFtm(uint256 _cost);
    event ChangedMaxCostFtm(uint256 _maxcost);
    event ChangedCostToken(uint256 _cost);
    event ChangedMaxCostToken(uint256 _maxcost);
    event ChangedMarketingAddress(address _marketing);
    event ChangedDev1Address(address _dev1);
    event ChangedDev2Address(address _dev2);

    // Constructor
    constructor(address _dev1, address _dev2, address _marketing, address _token, string memory _uri) ERC721("ProtofiNFT", "PNFT") {
        tokenCounter = 0;
        marketing = _marketing;
        dev1 = _dev1;
        dev2 = _dev2;
        uri = _uri;
        token = ERC20(_token);
    }

    /* MINTING */

    // Mint in Protofi
    function mintWithToken(uint256 _costUsed) public {
        // Get
        uint256 allow = token.allowance(msg.sender, address(this));
        uint256 balance = token.balanceOf(msg.sender);
        // Checks
        require(!pause, "ProtofiNFT: minting has been paused");
        require(_costUsed >= costToken, "ProtofiNFT: min cost isn't matched");
        require(_costUsed <= maxcostToken, "ProtofiNFT: max cost overload");
        require(balance >= _costUsed,  "ProtofiNFT: Balance too low");
        require(allow >= _costUsed,  "ProtofiNFT: Allowance too low");
        
        // Transfer coins
        token.transferFrom(msg.sender, address(this), _costUsed);

        // Minting
        // Get random tier
        uint8 tier = getRarity(costToken, maxcostToken, _costUsed);
        // Mint 
        _create(msg.sender, tier);
        // Spliting value
        handleSplitRewardToken(_costUsed);
    }

    // Mint in FTM
    function mint() public payable {
        // Checks
        require(!pause, "ProtofiNFT: minting has been paused");
        require(msg.value >= costFtm, "ProtofiNFT: min cost isn't matched");
        require(msg.value <= maxcostFtm, "ProtofiNFT: max cost overload");

        // Minting
        // Get random tier
        uint8 tier = getRarity(costFtm, maxcostFtm, msg.value);
        // Mint 
        _create(msg.sender, tier);
        // Spliting value
        handleSplitReward(msg.value);
    }
        
    // Special mint for airdrop
    function mintTo(address _receiver, uint8 _tier) external onlyWhitelist {
        _create(_receiver, _tier);
    }

    // Global mint function
    function _create(address _receiver, uint8 _tier) internal {
        // Check tier
        require(_tier > 0 && _tier < 6, "ProtofiNFT: tier value is invalid");
        // Mint NFT
        _safeMint(_receiver, tokenCounter);
        // Add Structure to mapping
        nfts[tokenCounter] = Protofi(tokenCounter, _tier, false);
        // Emit Creation event
        emit CreatedNFT(tokenCounter, _tier);
        // Increment counter
        tokenCounter = tokenCounter + 1;
    }

    // Split rewards
    function handleSplitRewardToken(uint256 _amount) private {
        // Split payment
        uint256 mintShare = _amount.div(100);
        uint256 devShare = mintShare.mul(splitTokenDev);
        uint256 marketingShare = _amount.sub(devShare.mul(2));
        // Send share
        token.transfer(dev1, devShare);
        token.transfer(dev2, devShare);
        token.transfer(marketing, marketingShare);
    }

    function handleSplitReward(uint256 _amount) private {
        // Split payment
        uint256 mintShare = _amount.div(100);
        uint256 devShare = mintShare.mul(splitFtmDev);
        uint256 marketingShare = _amount.sub(devShare.mul(2));
        // Send share
        payable(dev1).transfer(devShare);
        payable(dev2).transfer(devShare);
        payable(marketing).transfer(marketingShare);
    }

    /* GETTERS & SETTERS FOR CONTRACT */

    // Set Pause
    function setPause(bool _status) external onlyOwner {
        pause = _status;
    }

    // Set Rates
    function setBaseRate(uint8 _rateTier1, uint8 _rateTier2, uint8 _rateTier3, uint8 _rateTier4, uint8 _rateTier5) public onlyWhitelist {
        require((_rateTier1+_rateTier2+_rateTier3+_rateTier4+_rateTier5) == 100, "ProtofiNFT: rates do not adds up to 100%");
        baseRange = [_rateTier1, _rateTier2, _rateTier3, _rateTier4, _rateTier5];
    }
    function setMaxRate(uint8 _rateTier1, uint8 _rateTier2, uint8 _rateTier3, uint8 _rateTier4, uint8 _rateTier5) public onlyWhitelist {
        require((_rateTier1+_rateTier2+_rateTier3+_rateTier4+_rateTier5) == 100, "ProtofiNFT: rates do not adds up to 100%");
        maxbonusRange = [_rateTier1, _rateTier2, _rateTier3, _rateTier4, _rateTier5];
    }

    // Set Name Description
    function setTierName(string memory _nameTier1, string memory _nameTier2, string memory _nameTier3, string memory _nameTier4, string memory _nameTier5) public onlyWhitelist {
        tiersName = [_nameTier1, _nameTier2, _nameTier3, _nameTier4, _nameTier5];
    }
    function setTierDesc(string memory _nameTier1, string memory _nameTier2, string memory _nameTier3, string memory _nameTier4, string memory _nameTier5) public onlyWhitelist {
        tiersDesc = [_nameTier1, _nameTier2, _nameTier3, _nameTier4, _nameTier5];
    }

    // Get Rates
    function _baseRange() public view returns (uint8[5] memory) {
        return baseRange;
    }   
    function _maxbonusRange() public view returns (uint8[5] memory) {
        return maxbonusRange;
    }   

    // Set Mint fee and receiver
    function setCost(uint256 _cost) external onlyWhitelist {
        costFtm = _cost;
        emit ChangedCostFtm(_cost);
    }    

    function setTokenCost(uint256 _cost) external onlyWhitelist {
        costToken = _cost;
        emit ChangedCostToken(_cost);
    }

    function setMaxCost(uint256 _maxcost) external onlyWhitelist {
        maxcostFtm = _maxcost;
        emit ChangedMaxCostFtm(_maxcost);
    }    

    function setMaxTokenCost(uint256 _maxcost) external onlyWhitelist {
        maxcostToken = _maxcost;
        emit ChangedMaxCostToken(_maxcost);
    }

    function setMax(uint256 _max) external onlyWhitelist {
        require(_max > 0, "ProtofiNFT: max can't be zero");
        maxMintAmount = _max;
    }

    function setDev1(address _receiver) external onlyOwner {
        require(_receiver != address(0), "ProtofiNFT: address is null");
        dev1 = _receiver;
        emit ChangedDev1Address(_receiver);
    }    

    function setDev2(address _receiver) external onlyWhitelist {
        require(_receiver != address(0), "ProtofiNFT: address is null");
        dev2 = _receiver;
        emit ChangedDev2Address(_receiver);
    }

    function setMarketingReceiver(address _receiver) external onlyWhitelist {
        require(_receiver != address(0), "ProtofiNFT: address is null");
        marketing = _receiver;
        emit ChangedMarketingAddress(_receiver);
    }
    
    function setFtmSplit(uint256 _split) external onlyOwner {
        require(_split > 0, "ProtofiNFT: split can't be zero");
        splitFtmDev = _split;
        emit ChangedSplitFtm(_split);
    }

    function setTokenSplit(uint256 _split) external onlyOwner {
        require(_split > 0, "ProtofiNFT: split can't be zero");
        splitTokenDev = _split;
        emit ChangedSplitToken(_split);
    }

    // Set secondary currency
    function setToken(address _token) external onlyWhitelist {
        require(_token != address(0), "ProtofiNFT: address is null");
        token = ERC20(_token);
        emit ChangedToken(_token);
    }

    // Set URI
    function setURI(string memory _uri) external onlyWhitelist {
        uri = _uri;
    }

    /* NFTs METHODS */

    // Check account in Token balance
    function balanceFor(uint256 _amount) public view returns (bool){
        uint256 balance = token.balanceOf(msg.sender);
        return balance >= _amount;
    }
    // Check account in Token balance
    function allowanceFor(uint256 _amount) public view returns (bool){
        uint256 allow = token.allowance(msg.sender, address(this));
        return allow >= _amount;
    }

    // Return compiled Token URI
    function tokenURI(uint256 _id) public view virtual override returns (string memory){
        require(_exists(_id),"ProtofiNFT: query for nonexistent token");
        return formatTokenURI(nfts[_id].tier);
    }

    // Return Token Tier
    function tokenTier(uint256 _id) public view virtual returns (uint8){
        require(_exists(_id),"ProtofiNFT: query for nonexistent token");
        return nfts[_id].tier;
    }

    // Return Token Used
    function tokenUsed(uint256 _id) public view virtual returns (bool){
        require(_exists(_id),"ProtofiNFT: query for nonexistent token");
        return nfts[_id].used;
    }

    // Burn token for this user
    function useToken(uint256 _id, address _nftOwner) external onlyWhitelist {
        // Checks
        require(_exists(_id), "ProtofiNFT: query for nonexistent token");
        require(ownerOf(_id) == _nftOwner, "ProtofiNFT: Token not owned by sender");
        require(!nfts[_id].used, "ProtofiNFT: Token already used");
        // Use it
        nfts[_id].used = true;
        // Emit Used event
        emit UsedNFT(_id, _nftOwner);
    }
  
    /* FORMATING TOKEN URI */

    // Format json for URI
    function formatTokenURI(uint8 _tier) public view returns (string memory) {
        // Check tier
        require(_tier > 0 && _tier < 6, "ProtofiNFT: tier value is invalid");
        // Return Json
        return string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{',
                                    '"name": "', tiersName[_tier - 1],'",',
                                    '"description": "', tiersDesc[_tier - 1],'",',
                                    '"attributes": "",',
                                    '"image": "', uri, uint2str(_tier),'.png"',
                                '}'
                            )
                        )
                    )
                )
            );
    }

    // Convert uint into string
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
    
    /* UTILS FOR RANDOMIZATION */

    // Get Rarity Tier
    function getRarity(uint256 _baseCost, uint256 _maxCost, uint256 _paidCost) private view returns (uint8) {
        uint8[100] memory rarity;
        uint8[5] memory ranges = getRange(_baseCost, _maxCost, _paidCost);
        uint8 count = 0;
        uint8 y = 0;
        for (uint8 i = 0; i < 5; i++) {
            count += ranges[i];
            for (y ; y < count; y++) {
                rarity[y] = i+1;
            }
        }
        return rarity[random() % 100];
    }

    // Get odds for each tier depending on amount paid
    function getRange(uint256 _baseCost, uint256 _maxCost, uint256 _paidCost) public view returns (uint8[5] memory) {
        uint8[5] memory range;
        uint8 maxRange;
        uint256 ratio;
        // Rarity ranges are calculated by rate * (paid - min) / (max - min)

        // Case Max = Min
        if(_baseCost == _maxCost) {
            return baseRange;
        }
        
        // Calculating each steps
        for (uint8 i = 0; i < 5; i++) {
            // Case rates are increasing
            if(baseRange[i] <= maxbonusRange[i]) {
                maxRange =  maxbonusRange[i] - baseRange[i];
                ratio = uint256(maxRange).mul(_paidCost.sub(_baseCost)).div(_maxCost.sub(_baseCost));
                range[i] = baseRange[i] + uint8(ratio);
            } 
            // Case rates are decreasing
            else {
                maxRange =  baseRange[i] - maxbonusRange[i];
                ratio = uint256(maxRange).mul(_paidCost.sub(_baseCost)).div(_maxCost.sub(_baseCost));
                range[i] = baseRange[i] - uint8(ratio);
            }
        }
        return range;
    }

    function random() private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, tokenCounter)));
    }
}