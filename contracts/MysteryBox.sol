// Multiple PixelPimp Fixed MysteryBox contract
// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MysteryBox is ERC1155Holder, ERC721Holder {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**
        Card Struct
     */
    struct Card {
        uint256 cardType; // 0: ERC721, 1: ERC1155
        bytes32 key; // card key which was generated with collection and tokenId
        address collectionId;   // collection address
        uint256 tokenId;        // token id of collection
        uint256 amount;  // added nft token balances
    }

    address public factory;
    address public owner;

    address public tokenAddress;
    uint256 public price;	
    uint256 constant public PERCENTS_DIVIDER = 1000;
    uint256 public serviceFee = 15;  // 1.5%	
    

    string public boxName; 
    string public boxUri;    
    
    bool public status = true;    

    // This is a set which contains cardKey
    mapping(bytes32 => Card) private _cards;
    EnumerableSet.Bytes32Set private _cardIndices;
    
    // The amount of cards in this lootbox.
    uint256 public cardAmount;

    event AddToken(uint256 cardType, bytes32 key, address collectionId, uint256 tokenId, uint256 amount, uint256 _cardAmount);
    event AddTokenBatch(uint256 cardType, bytes32[] keys, address collectionId, uint256[] tokenIds, uint256[] amounts, uint256 _cardAmount);
    event SpinResult(address player, uint256 times, bytes32[] keys, uint256 _cardAmount);
    event RemoveCard(bytes32 key, uint256 removeAmount, uint256 _cardAmount);
    event EmergencyWithdrawAllCards(bytes32[] keys, uint256 _cardAmount);

    event PriceChanged(uint256 newPrice);
    event PaymentTokenChanged(address newTokenAddress);
    event MysteryBoxStatus(bool boxStatus);
    event OwnerShipChanged(address newAccount);
    event MysteryBoxNameChanged(string newName);
    event MysteryBoxUriChanged(string newUri);

    constructor() {
        factory = msg.sender;
    }

    function initialize(string memory _name, 
                string memory _uri,
                address _tokenAddress,
                uint256 _price,
                address _owner
                ) public onlyFactory {        
        boxName = _name;
        boxUri  = _uri;
        tokenAddress = _tokenAddress;
        price = _price;       
        owner = _owner;            
    }

    // ***************************
    // For Change Parameters ***********
    // ***************************
    function changePrice(uint256 newPrice) public onlyOwner {
        price = newPrice;
        emit PriceChanged(newPrice);
    }
    function changePaymentToken(address _newTokenAddress) external onlyOwner {
        tokenAddress = _newTokenAddress;
        emit PaymentTokenChanged(_newTokenAddress);
    }
    function enableThisMysteryBox() public onlyOwner {
        status = true;
        emit MysteryBoxStatus(status);
    }

    function disableThisMysteryBox() public onlyOwner {
        status = false;
        emit MysteryBoxStatus(status);
    }

    function transferOwner(address account) public onlyOwner {
        require(account != address(0), "Ownable: new owner is zero address");
        owner = account;
        emit OwnerShipChanged(account);
    }
    function removeOwnership() public onlyOwner {
        owner = address(0x0);
        emit OwnerShipChanged(owner);
    }
    function changeMysteryBoxName(string memory name) public onlyOwner {
        boxName = name;
        emit MysteryBoxNameChanged(name);
    }

    function changeMysteryBoxUri(string memory _uri) public onlyOwner {
        boxUri = _uri;
        emit MysteryBoxUriChanged(_uri);
    }

    

    // ***************************
    // For Main function ***********
    // ***************************

    function addToken(uint256 cardType, address collection, uint256 tokenId, uint256 amount) public onlyOwner {        
        require((cardType == 0 || cardType == 1), "Invalid card type");
        
        if (cardType == 0){
            require(IERC721(collection).ownerOf(tokenId) == msg.sender, "You are not token owner");
            IERC721(collection).safeTransferFrom(msg.sender, address(this), tokenId);
        }else if (cardType == 1){
            require(IERC1155(collection).balanceOf(msg.sender, tokenId) >= amount, "You don't have enough Tokens");
            IERC1155(collection).safeTransferFrom(msg.sender, address(this), tokenId, amount, "Add Card");
        }        

        bytes32 key = itemKeyFromId(collection, tokenId);
        if(_cards[key].amount == 0) {
            _cardIndices.add(key);
        }
        _cards[key].cardType = cardType;
        _cards[key].key = key;
        _cards[key].collectionId = collection;
        _cards[key].tokenId = tokenId;
        _cards[key].amount = _cards[key].amount.add(amount);       
        
        cardAmount = cardAmount.add(amount);
        emit AddToken(cardType, key, collection, tokenId, amount, cardAmount);
    }

    function addTokenBatch(uint256 cardType, address collection, uint256[] memory tokenIds, uint256[] memory amounts) public onlyOwner {
        require(tokenIds.length > 0 && tokenIds.length == amounts.length, 'Invalid Token ids');
        require((cardType == 0 || cardType == 1), "Invalid card type");

        bytes32[] memory keys = new bytes32[](tokenIds.length);
        for(uint256 i = 0 ; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amounts[i];

            if (cardType == 0){
                // ERC721
                require(IERC721(collection).ownerOf(tokenId) == msg.sender, "You are not token owner");
                IERC721(collection).safeTransferFrom(msg.sender, address(this), tokenId);
            }else if (cardType == 1){
                // ERC1155
                require(IERC1155(collection).balanceOf(msg.sender, tokenId) >= amount, "You don't have enough Tokens");
                IERC1155(collection).safeTransferFrom(msg.sender, address(this), tokenId, amount, "Add Card");
            }        

            keys[i] = itemKeyFromId(collection, tokenId);
            if(_cards[keys[i]].amount == 0) {
                _cardIndices.add(keys[i]);
            }
            _cards[keys[i]].cardType = cardType;
            _cards[keys[i]].key = keys[i];
            _cards[keys[i]].collectionId = collection;
            _cards[keys[i]].tokenId = tokenId;
            _cards[keys[i]].amount = _cards[keys[i]].amount.add(amount);       
            
            cardAmount = cardAmount.add(amount);            
        }

        emit AddTokenBatch(cardType, keys, collection, tokenIds, amounts, cardAmount);
    }

    function spin(uint256 times) external payable onlyHuman {
        require(status, "This lootbox is disabled.");        
        require(cardAmount > 0, "There is no card in this lootbox anymore.");
        require(times > 0, "Times can not be 0");
        require(times <= 20, "Over times.");
        require(times <= cardAmount, "You play too many times.");



        uint256 tokenAmount = price.mul(times);
        uint256 feeAmount = tokenAmount.mul(serviceFee).div(PERCENTS_DIVIDER);		
		uint256 ownerAmount = tokenAmount.sub(feeAmount);
        if (tokenAddress == address(0x0)) {
            require(msg.value >= tokenAmount, "too small amount");

			if(feeAmount > 0) {
				payable(factory).transfer(feeAmount);			
			}					
			payable(owner).transfer(ownerAmount);		
        } else {
            IERC20 governanceToken = IERC20(tokenAddress);	

			require(governanceToken.transferFrom(msg.sender, address(this), tokenAmount), "insufficient token balance");		
			// transfer governance token to factory
			if(feeAmount > 0) {
				require(governanceToken.transfer(factory, feeAmount));		
			}			
			// transfer governance token to owner		
			require(governanceToken.transfer(owner, ownerAmount));	
        }
    
        bytes32[] memory keys = new bytes32[](times);     

        for (uint256 i = 0; i < times; i++) {
            // get card randomly
            
            bytes32 cardKey = getCardKeyRandmly();
            keys[i] = cardKey;            
            cardAmount = cardAmount.sub(1);

            require(_cards[cardKey].amount > 0, "No enough cards of this kind in the lootbox.");
            if (_cards[cardKey].cardType == 0) {  
                // ERC721              
                IERC721(_cards[cardKey].collectionId).safeTransferFrom(address(this), msg.sender, _cards[cardKey].tokenId);
            } else if (_cards[cardKey].cardType == 1) {   
                // ERC1155             
                IERC1155(_cards[cardKey].collectionId).safeTransferFrom(address(this), msg.sender, _cards[cardKey].tokenId, 1, "Your prize from Pixelpimp MysteryBox");
            }
            _cards[cardKey].amount = _cards[cardKey].amount.sub(1);
            if(_cards[cardKey].amount == 0) {
                _cardIndices.remove(cardKey);
            }            
        }
        emit SpinResult(msg.sender, times, keys, cardAmount);
    }


    // ***************************
    // view card information ***********
    // ***************************
     
    function cardKeyCount() view public returns(uint256) {
        return _cardIndices.length();
    }

    function cardKeyWithIndex(uint256 index) view public returns(bytes32) {
        return _cardIndices.at(index);
    }
    
    function allCards() view public returns(Card[] memory cards) {
        uint256 cardsCount = cardKeyCount();
        cards = new Card[](cardsCount);        

        for(uint i = 0; i < cardsCount; i++) {
            cards[i] = _cards[cardKeyWithIndex(i)];           
        }
    }


    // ***************************
    // emergency call information ***********
    // ***************************

    function emergencyWithdrawCard(address collectionId, uint256 tokenId, uint256 amount) public onlyOwner {
        bytes32 cardKey = itemKeyFromId(collectionId, tokenId);
        Card memory card = _cards[cardKey];
        require(card.tokenId != 0 && card.collectionId != address(0x0), "Invalid Collection id and token id");
        require(card.amount >= amount, "Insufficient balance");
        require(amount > 0, "Insufficient amount");
        if (card.cardType == 0) {
            // withdraw single card
            IERC721(card.collectionId).safeTransferFrom(address(this), msg.sender, card.tokenId);                    
        } else if (card.cardType == 1){
            // withdraw multiple card
            IERC1155(card.collectionId).safeTransferFrom(address(this), msg.sender, card.tokenId, amount, "Reset MysteryBox");
        }  
        cardAmount = cardAmount.sub(amount);
        _cards[cardKey].amount = _cards[cardKey].amount.sub(amount);
        if(_cards[cardKey].amount == 0) {
            _cardIndices.remove(cardKey);
        }   
        emit RemoveCard(cardKey, amount, cardAmount);      
    }

    function emergencyWithdrawAllCards() public onlyOwner {
        bytes32[] memory keys = new bytes32[](cardKeyCount());
        for(uint256 i = 0 ; i < cardKeyCount(); i++) {
            bytes32 key = cardKeyWithIndex(i);
            keys[i] = key;
            if(_cards[key].amount > 0) {
                Card memory card = _cards[key];
                if (card.cardType == 0) {
                    // withdraw single card
                    IERC721(card.collectionId).safeTransferFrom(address(this), msg.sender, card.tokenId);                    
                } else if (card.cardType == 1){
                    // withdraw multiple card
                    IERC1155(card.collectionId).safeTransferFrom(address(this), msg.sender, card.tokenId, card.amount, "Reset MysteryBox");
                }   
                cardAmount = cardAmount.sub(_cards[key].amount);       
                _cards[key].amount = 0;
                _cardIndices.remove(key);               
            }
        }        
        emit EmergencyWithdrawAllCards(keys,cardAmount);
    }


    // ***************************
    // general function ***********
    // ***************************
    function getCardKeyRandmly() view private returns(bytes32) {
        uint256 randomNumber =  uint256(keccak256(abi.encode(block.timestamp, block.difficulty, block.number))).mod(cardAmount);
        uint256 amountSum = 0;
        for(uint i = 0; i < cardKeyCount(); i++) {
            amountSum = amountSum.add(_cards[cardKeyWithIndex(i)].amount);
            if (amountSum > randomNumber){
                return cardKeyWithIndex(i);
            }
        }    
        return cardKeyWithIndex(0);
    }
    function isContract(address _addr) view private returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function itemKeyFromId(address _collection, uint256 _token_id) public pure returns (bytes32) {
        return keccak256(abi.encode(_collection, _token_id));
    }


    // ***************************
    // Modifiers information ***********
    // ***************************    
    modifier onlyHuman() {
        require(!isContract(address(msg.sender)) && tx.origin == msg.sender, "Only for human.");
        _;
    }

    modifier onlyFactory() {
        require(address(msg.sender) == factory, "Only for factory.");
        _;
    }

    modifier onlyOwner() {
        require(address(msg.sender) == owner,  "Only for owner.");
        _;
    }

}