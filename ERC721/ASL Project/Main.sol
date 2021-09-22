// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// All ERC721 files are from openzeppelin as per standard, but names and locations were changed to put them in the same directory
import "./OpenZeppelin/ERC721.sol";
import "./OpenZeppelin/Ownable.sol";
import "./OpenZeppelin/SafeMath.sol";
import "./OpenZeppelin/Strings.sol";


contract ASLProject is ERC721, Ownable {
    using Strings for uint256; // Added for testing TokenURI without api
    using SafeMath for uint256; // Added to split payment, but no longer needed
    
    uint256 public maxTokens = 100;
    uint256 public teamReserved = 10;
    uint256 public price = .05 ether;
    uint256 public maxPerTx = 5;
    uint256 public tokensForPublic = 90; // Reservations max, and once sale is public, this is max mintable for public
    uint256 public totalSupply = 0; // Number already minted
    uint256 public reservationStartTime = 3093527998799; // Change these times. Current epoch time year 99999
    uint256 public mintingStartTime = 3093527998799;
    uint256 public saleIsPublicTime = 3093527998799;
    

    bool public saleIsPaused = true; // Pause sale
    bool public licenseLocked = false; // No more changes can be made once locked
    bool public reservationsArePaused = true; // Pause reservations
    
    // string public ASL_Provenance = ""; // Set Provenance once calculated
    
    string private baseURI; // Base URI
    
    mapping (address => uint256) allowedTokens; // Mapping to keep track of reservations based on address
    
    constructor() ERC721("ASL Project", "ASL") { // Could add more params such as baseURI if api is done before 
        // Could add optional minting for team right at deployment
    }
    
    function reserve(uint256 amount) public payable { // Reservations function
        require(block.timestamp < saleIsPublicTime, "Sale is public. Reservations no longer taken"); // Check that sale is not public yet
        require(block.timestamp >= reservationStartTime, "It's not time to reserve tokens yet"); // Check that time is right
        require(!reservationsArePaused, "Reservations are not live"); // Check that reservations are not paused
        require(msg.sender==tx.origin,"Only a user may interact with this contract"); // Make sure no contract reserves. Could remove.
        require(amount <= maxPerTx, "Cannot reserve more than 5 token"); // Check limit per tx
        require(tokensForPublic - amount >= 0, "Cannot exceed max reserved tokens"); // Stay below total tokens to be reserved
        require(allowedTokens[msg.sender] == 0, "You have already reserved tokens"); // Check that they haven't reserved already. Could remove. 
        require(msg.value >= price * amount, "Ether sent is not correct"); // Check that amount is right

        allowedTokens[msg.sender] = amount; // Reserve tokens

        tokensForPublic -= amount; // Decrease available reservations
    }
    
    // Could change to payable
    function mint(uint256 amount) public payable {
        if (allowedTokens[msg.sender] != 0 || block.timestamp < saleIsPublicTime) // People who reserved before public sale can still mint for free + gas after sale goes live
        {
            require(block.timestamp >= mintingStartTime, "It's not time to mint yet"); // Check that its minting time
            require(!saleIsPaused, "Sale is not live"); // Check that sale is not paused
            require(allowedTokens[msg.sender] >= amount, "You can't mint more tokens than you have reserved"); // Can't mint more than reserved
            
            // subtract minted tokens from allowedTokens
            allowedTokens[msg.sender] -= amount;
            
            // Mint requested amount
            for (uint256 i; i < amount; i++) {
                _safeMint(msg.sender, totalSupply + i);
            }
            
            // Add amount to total minted tokens so far
            totalSupply += amount;
        }
        else {
            require(totalSupply <= maxTokens, "Sale has already ended");
            require(!saleIsPaused, "Sale is not live");
            require(amount + totalSupply <= tokensForPublic, "Cannot exceed max supply");
            require(amount <= maxPerTx, "Cannot mint more than 5 tokens");
            require(msg.value >= price * amount, "Ether sent is not correct");


            for (uint256 i; i < amount; i++) { // Mint
                _safeMint(msg.sender, totalSupply + i);
            }
            
            totalSupply += amount; // Add minted amount to total supply
        }
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
        saleIsPaused = !saleIsPaused;
    }
    
    // Pause reservations in case anything happens
    function flipReservationState() public onlyOwner {
        require(!licenseLocked, "License locked, cannot make changes anymore");
        reservationsArePaused = !reservationsArePaused;
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
