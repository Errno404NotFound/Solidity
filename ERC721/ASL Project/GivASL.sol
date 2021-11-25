// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// All ERC721 files are from openzeppelin as per standard, but names and locations were changed to put them in the same directory
import "./OpenZeppelin/ERC721.sol";
import "./OpenZeppelin/Ownable.sol";
import "./OpenZeppelin/Strings.sol";
import "./OpenZeppelin/ReentrancyGuard.sol";
import "./OpenZeppelin/MerkleProof.sol";

contract GivASL is ERC721, Ownable, ReentrancyGuard {

    using Strings for uint256; // Added for testing TokenURI without api
    
    using MerkleProof for *;

    bytes32 public merkleRoot;

    uint256 public maxTokens = 8258;
    uint256 public teamReserved = 100;
    uint256 public price = .048 ether;
    uint256 public maxPerTx = 26;
    uint256 public totalSupply = 0; // Number already minted
    uint256 public totalReserved = 0; // Amount open to public for reservations
    uint256 public presaleStartTime = 3093527998799; // Change these times. Current epoch time year 99999
    uint256 public reservationStartTime = 3093527998799; 
    uint256 public mintingStartTime = 3093527998799;
    uint256 public saleIsPublicTime = 3093527998799;
    // uint256 public tokensForPublic = 90; // Reservations max, and once sale is public, this is max mintable for public
    

    bool public licenseLocked = false; // No more changes can be made once locked
    bool public saleActive = true; // Pause sale
    bool public reservationsActive = true; // Pause reservations
    
    // string public ASL_Provenance = ""; // Set Provenance once calculated
    
    string private baseURI; // Base URI
    
    mapping (address => uint256) allowedTokens; // Mapping to keep track of reservations based on address
    mapping (address => uint256) mintedPerAccount; // Minted per whitelisted account 
    
    constructor() ERC721("GivASL", "ASL") Ownable() ReentrancyGuard() { 

    }
    
function claim(uint256 index, address account, uint256 amountReserved, uint256 amountToMint, bytes32[] calldata merkleProof) nonReentrant external payable {
        require(block.timestamp >= presaleStartTime, "Presale has not started yet");
        require(saleActive, "Sale is not currently active");
        require(totalSupply + totalReserved + amountToMint <= maxTokens - teamReserved, "Sale has already ended");
        require(merkleRoot != bytes32(0), "Whitelist has not been set");
        require(amountToMint + mintedPerAccount[account] <= amountReserved, "Cannot mint more than reserved");
        require(msg.value >= amountToMint * price, "Amount sent is not correct");

        // Verify the merkle proof to make sure given information matches whitelist saved info.
        bytes32 node = keccak256(abi.encodePacked(index, account, amountReserved));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "Not whitelisted");

        mintedPerAccount[account] += amountToMint;
        
        for (uint256 i = 0; i < amountToMint; i++) {
            _safeMint(account, totalSupply + i);
        }

        totalSupply += amountToMint;
    }

    function reserve(uint256 amount) public payable { // Reservations function
        require(block.timestamp < saleIsPublicTime, "Sale is public. Reservations no longer taken"); // Check that sale is not public yet
        require(block.timestamp >= reservationStartTime, "It's not time to reserve tokens yet"); // Check that time is right
        require(reservationsActive, "Reservations are not currently active"); // Check that reservations are not paused
        // require(msg.sender==tx.origin,"Only a user may interact with this contract"); // Make sure no contract reserves. Could remove.
        require(amount <= maxPerTx, "Cannot reserve more than 26 tokens"); // Check limit per tx
        require(totalReserved + amount <= maxTokens - teamReserved, "Cannot exceed max supply"); // Stay below total supply
        require(allowedTokens[msg.sender] == 0, "You have already reserved tokens"); // Check that they haven't reserved already. Could remove. 
        require(msg.value >= price * amount, "Ether sent is not correct"); // Check that amount is right

        allowedTokens[msg.sender] = amount; // Reserve tokens

        totalReserved += amount;
    }
    
    // Could change to payable
    function mint(uint256 amount) external payable nonReentrant {
        if (allowedTokens[msg.sender] != 0 || block.timestamp < saleIsPublicTime) // People who reserved before public sale can still mint for free + gas after sale goes live
        {
            require(block.timestamp >= mintingStartTime, "Minting time has not started yet"); // Check that its minting time
            require(saleActive, "Sale is not currently active"); // Check that sale is not paused
            require(allowedTokens[msg.sender] >= amount, "You can't mint more tokens than you have reserved"); // Can't mint more than reserved
            
            // subtract minted tokens from allowedTokens
            allowedTokens[msg.sender] -= amount;
            
            // Mint requested amount
            for (uint256 i; i < amount; i++) {
                _safeMint(msg.sender, totalSupply + i);
            }
            
            // Add amount to total minted tokens so far
            totalSupply += amount;
            totalReserved -= amount;
        }
        else {
            require(block.timestamp >= mintingStartTime, "Minting time has not started yet"); // Check that its minting time
            require(saleActive, "Sale is not live");
            require(totalSupply + totalReserved + amount <= maxTokens - teamReserved, "Sale has already ended");
            // require(amount + totalSupply <= ., "Cannot exceed max supply");
            require(amount <= maxPerTx, "Cannot mint more than 5 tokens");
            require(msg.value >= price * amount, "Ether sent is not correct");

            for (uint256 i; i < amount; i++) { // Mint
                _safeMint(msg.sender, totalSupply + i);
            }
            
            totalSupply += amount; // Add minted amount to total supply
        }
    }
    
    function setPresaleStartTime(uint256 _startTime) public onlyOwner { 
         require(!licenseLocked, "License locked, cannot make changes anymore");
         presaleStartTime = _startTime;
    }

    // Set reservation start time
    function setReservationStartTime(uint256 _startTime) public onlyOwner {
         require(!licenseLocked, "License locked, cannot make changes anymore");
         reservationStartTime = _startTime;
    }
    
    // Set minting start time 
    function setMintingStartTime(uint256 _startTime) public onlyOwner {
         require(!licenseLocked, "License locked, cannot make changes anymore");
         mintingStartTime = _startTime;
    }

    function setPublicSaleStartTime(uint256 _startTime) public onlyOwner { 
         require(!licenseLocked, "License locked, cannot make changes anymore");
         saleIsPublicTime = _startTime;
    }

    function setMerkleRoot(bytes32 root) public onlyOwner {
        require(!licenseLocked, "License locked, cannot make changes anymore");
        merkleRoot = root;
    }
    
    // Set base URI
    function setBaseURI(string memory _newURI) public onlyOwner {
        require(!licenseLocked, "License locked, cannot make changes anymore");
        baseURI = _newURI;
    }
    
    // Used for test because using IPFS folder for .json files
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // Check that tokenId exists and has been minted 
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        // Check that baseURI is not an empty string
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    }
    
    // Pause sale in case anything happens
    function flipSaleState() public onlyOwner {
        require(!licenseLocked, "License locked, cannot make changes anymore");
        saleActive = !saleActive;
    }
    
    // Pause reservations in case anything happens
    function flipReservationState() public onlyOwner {
        require(!licenseLocked, "License locked, cannot make changes anymore");
        reservationsActive = !reservationsActive;
    }
    
    // Lock license so that no more owner only changes can be made
    function lockLicense() public onlyOwner {
        require(!licenseLocked, "License locked, cannot make changes anymore");
        licenseLocked = !licenseLocked;
    }
    
    // Override default baseURI function to return new URI
    function _baseURI() internal view virtual override returns (string memory) { 
        return baseURI;
    }
    
    // Returns number of reservations for given address
    function reservationsByOwner(address _owner) external view returns (uint256) {
        return allowedTokens[_owner];
    }
    
    // Function to mint team reserved tokens
    function teamMint(address _to, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Can't mint 0 tokens"); // Save gas in case accidentally call mint 0. Could remove to just save the gas from the require
        require(_amount <= teamReserved, "Cannot exceed reserved supply"); // Check that amount doesnt exceed reserved amount
        
        for(uint256 i; i < _amount; i++){
            _safeMint(_to, totalSupply + i);
        }
        
        // Subtract from reserved amount
        teamReserved -= _amount;
        // Add to total supply so far
        totalSupply += _amount;
    }
    
    // Send given amount to given address
    function withdraw(address _to, uint256 _amount) public onlyOwner {
        require(_amount <= address(this).balance, "Not enough money in the balance"); // Check that it doesn't exceed max balance
        (bool sent, ) = _to.call{value: _amount}("");
        require(sent, "Failed to send Ether"); // Check that it sent
    }
    
}
