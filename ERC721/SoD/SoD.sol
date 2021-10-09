// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ExtraContracts/ERC721.sol";
import "./ExtraContracts/Ownable.sol";
import "./ExtraContracts/SafeMath.sol";

contract PIXLS is ERC721, Ownable {
    using Strings for uint256;
    using SafeMath for uint256;
    
    uint256 public maxSwords = 2000; // Max supply
    uint256 public teamReserved = 15; // 
    uint256 public price = .025 ether;
    uint256 public maxPerTx = 10;
    uint256 public totalSupply = 0;
    uint256 public mintingStartTime = 3093527998799; // Change starting time, currently set to year 99999
    
    bool public licenseLocked = false;
    
    string private baseURI;

    constructor() ERC721("Swords Of Destiny", "SWORD") {
        // Add minting 1 at launch
    }
        
    function mint(uint256 _amount) public payable {
        require(totalSupply < maxSwords, "Sale has already ended");
        require(block.timestamp >= mintingStartTime, "It's not time to mint yet");
        require(_amount <= maxPerTx, "Cannot mint more than 10 tokens per transaction");
        require(totalSupply + _amount <= maxSwords - teamReserved, "Cannot exceed max supply");
        require(msg.value >= price * _amount, "Ether sent is not correct");
        
        for (uint256 i; i < _amount; i++) {
            _safeMint(msg.sender, totalSupply + i);
        }
        
        totalSupply += _amount;
    }

    function setMintingStartTime(uint256 _startTime) public onlyOwner {
         require(!licenseLocked, "License locked, cannot make changes anymore");
         mintingStartTime = _startTime;
    }
    
    function setBaseURI(string memory _newURI) public onlyOwner {
        require(!licenseLocked, "License locked, cannot make changes anymore");
        baseURI = _newURI;
    }
    
    function lockLicense() public onlyOwner {
        require(!licenseLocked, "License locked, cannot make changes anymore");
        licenseLocked = !licenseLocked;
    }
    
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
    
    function teamMint(address _to, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Can't mint 0 tokens");
        require(_amount <= teamReserved, "Cannot exceed reserved supply");
        
        for(uint256 i; i < _amount; i++){
            _safeMint(_to, totalSupply + i);
        }
        
        teamReserved -= _amount;
        totalSupply += _amount;
    }
    
    function withdraw(address _to, uint256 _amount) public onlyOwner {
        require(_amount <= address(this).balance, "Not enough money in the balance");
        (bool sent, ) = _to.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }
}
