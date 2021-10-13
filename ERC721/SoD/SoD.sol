// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ExtraContracts/ERC721.sol";
import "../ExtraContracts/Ownable.sol";
import "../ExtraContracts/ReentrancyGuard.sol";
import "../ExtraContracts/MerkleProof.sol";

contract SoDWhitelist is ERC721, Ownable, ReentrancyGuard {

    using MerkleProof for *;

    bytes32 public immutable merkleRoot; // Used for whitelist check

    uint256 public maxSwords = 2222; // Max supply
    uint256 public teamReserved = 50; // 15 for team, 35 for events/giveaways
    uint256 public price = .025 ether; 
    uint256 public maxPerTx = 10; 
    uint256 public totalSupply = 0; 
    uint256 public mintingStartTime = 3093527998799; // Change starting time, currently set to year 99999
    uint256 public presaleStartTime = 3093527998799; // Change starting time, currently set to year 99999
    
    bool public licenseLocked = false; // Once locked nothing can be changed anymore
    
    string private baseURI; // Site api link for OS to pull metadata from

    mapping(address => uint256) public mintedPerAccount; // Minted per whitelisted account

    constructor(string _name, string _tokenName) ERC721(_name, _tokenName) Ownable() ReentrancyGuard() {

    }

    // Claim whitelisted tokens using merkle tree
    function claim(uint256 index, address account, uint256 amountReserved, uint256 amountToMint, bytes32[] calldata merkleProof) external {
        require(merkleRoot, "Root has not yet been set");
        require(block.timestamp >= presaleStartTime, "Presale has not started yet");
        require(amountToMint + mintedPerAccount[account] < amountReserved, "Cannot mint more than reserved");

        // Verify the merkle proof to make sure given information matches whitelist saved info.
        bytes32 node = keccak256(abi.encodePacked(index, account, amountReserved));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "Invalid proof.");

        mintedPerAccount[account] += amountToMint;
        
        for (uint256 i = 0; i < amountToMint; i++) {
            _safeMint(account, totalSupply + i);
        }

        totalSupply += amountToMint;
    }

    // 
    function mint(uint256 _amount) nonReentrant() public payable {
        require(totalSupply < maxSwords, "Sale has already ended");
        require(block.timestamp >= mintingStartTime, "Sale has not started yet");
        require(_amount <= maxPerTx, "Cannot mint more than 10 tokens per transaction");
        require(totalSupply + _amount <= maxSwords - teamReserved, "Cannot exceed max supply");
        require(msg.value >= price * _amount, "Ether sent is not correct");
        
        for (uint256 i; i < _amount; i++) {
            _safeMint(msg.sender, totalSupply + i);
        }
        
        totalSupply += _amount;
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

    function setMerkleRoot(bytes32 _root) public onlyOwner {
        require(!merkleRoot, "Root already set, no changes can be made to it.");
        merkleRoot = _root;
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
    
    function withdraw(address _to, uint256 _amount) public onlyOwner {
        require(_amount <= address(this).balance, "Not enough money in the balance");
        (bool sent, ) = _to.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }
}
