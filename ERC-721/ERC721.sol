// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

import "../interfaces/Ierc-721.sol";

contract ERC721 is Ierc721{

    address proxy;                                                                          // Dirección del proxy
    mapping(uint256 => address) private owners;                                             // Asocia cada NFT a su dirección
    mapping(address => uint256) private balances;                                           // Cantidad de tokens asociados a una direccion
    mapping(uint256 => address) private tokenApprovals;                                     // Address que indica la dirección que tiene permisos para administrar ese token.
    mapping(address => mapping(address => bool)) private operatorApprovals;                 // Asociación entre una dirección y otras que tiene permisos o no para administrar TODOS los tokens.
    mapping(address => mapping(uint256 => uint256)) private NFTs;                            // Asocia a una dirección la lista de NFTs que posee
    uint256 constant private FIRST_TOKEN = 9999999999;

    // Modificador para limitar una función al owner unicamente
    modifier onlyProxy {
        require(msg.sender == proxy);
        _;
    }

    constructor (address _proxy){
        proxy = _proxy;
    }

    /*  Funciones  */

    // Devuelve la cantidad de token de una asociados a una dirección
    function balanceOf(address _owner) public override view returns (uint256){
        require(_owner != address(0),"BalanceOf Error: Address 0 ins't valid");
        return balances[_owner];
    }

    // Devuelve el propietario de un token concreto
    function ownerOf(uint256 _tokenId) public override view returns (address){
        address ad = owners[_tokenId];
        require(ad != address(0),"OwnerOf Error: This token doesn't exist.");
        return ad;
    }

    // Función de minteo
    function mint(address _address, uint256 _tokenId) public onlyProxy {
        addUser(_address, _tokenId);
        balances[_address] += 1;
        owners[_tokenId] = _address;
        
        //Evento de emisión de un token nuevo (emitido desde las direccion 0)
        emit Transfer(address(0), msg.sender, _tokenId);
    }

    // Función para transferir un token entre dos direcciones
    function transferFrom(address _from, address _to, uint256 _tokenId) public override payable{
        require(_from != address(0),"TransferFrom Error: Address 0 ins't valid.");
        require(_to != address(0),"TransferFrom Error: Address 0 ins't valid.");
        require(_from == ownerOf(_tokenId),"TransferFrom Error: Ths token not allow to from address.");
        require(OwnerOrApproved(msg.sender,_tokenId),"Transfer Error: The source address does not have the token.");
        _transfer(_from, _to, _tokenId);
    }

    // Función que comprueba si es el propietario del token o una cuenta administradora de esa dirección.
    function OwnerOrApproved(address _sender, uint256 _tokenId) public view returns (bool){
        require(ownerOf(_tokenId) != address(0),"OwnerOrApproved Error: This token doesn't exists.");
        address _owner = ownerOf(_tokenId);
        return (_sender == _owner || isApprovedForAll(_owner,_sender) || getApproved(_tokenId) == _sender);
    }

    // Función para transferir un token entre dos direcciones
    function transferProxy(address _from, address _to, uint256 _tokenId) public onlyProxy{
        _transfer(_from, _to, _tokenId);
    }

    // Función interna que realiza la lógica de la transferencia.
    function _transfer(address _from, address _to, uint256 _tokenId) internal virtual{
        removeUser(_from, _tokenId);
        addUser(_to, _tokenId);
        balances[_from] -= 1;
        balances[_to] += 1;
        owners[_tokenId] = _to;
        emit Transfer(_from, _to, _tokenId);

    }

    // PENDIENTE DE VER
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) public override payable{
     
    }

    // PENDIENTE DE VER
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public override payable{
    
    }

    // Aprueba a una dirección para que gestione el token.
    function approve(address _approved, uint256 _tokenId) public override payable{
        address ownerToken = ownerOf(_tokenId);
        require(_approved != ownerToken,"Approval failed: the addresses should be different.");
        require(ownerToken == msg.sender,"Approval failed, you don't have permissions for that token.");

       tokenApprovals[_tokenId] = _approved;
       emit Approval(ownerToken,_approved,_tokenId);
    }

    // Función para hacer que otra dirección tenga o no permisos para la gestión de nuestros tokens
    function setApprovalForAll(address _operator, bool _approved) public override{
        require(_operator != msg.sender,"setApprovalForAll failed: the addresses should be different.");

        operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender,_operator,_approved);
    }

    // Devuelve la diección que tiene permisos para usar ese token.
    function getApproved(uint256 _tokenId) public override view returns (address){
        require(ownerOf(_tokenId) != address(0),"getApproved Error: This token doesn't exists.");
        return tokenApprovals[_tokenId];
    }

    // Devuelve la dirección tiene permitido el uso de nuestros tokens
    function isApprovedForAll(address _owner, address _operator) public override view returns(bool){
        return operatorApprovals[_owner][_operator];
    }


    
    function isInList(address _address, uint256 _tokenId)internal view returns(bool)
    {
        //Si no está devuelve false, ya que su valor si no existe todavía sera todo 0.
        return NFTs[_address][_tokenId] != 0;
    }

    function addUser(address _address, uint256 _tokenId) internal
    {
        if(balanceOf(_address)==0){
            NFTs[_address][FIRST_TOKEN] = FIRST_TOKEN;
        }
        require(!isInList(_address, _tokenId));
        //el nuevo elemento apuntará al que antes era el segundo
        NFTs[_address][_tokenId] = NFTs[_address][FIRST_TOKEN];
        //el primer elemento ahora apunta a este nuevo.
        NFTs[_address][FIRST_TOKEN] = _tokenId;
    }

    function removeUser(address _address,uint256 _tokenId) internal {
        require(isInList(_address, _tokenId));
        uint256 addprevia = getPrevUser(_address,_tokenId);
        NFTs[_address][addprevia] = NFTs[_address][_tokenId];
        NFTs[_address][_tokenId] = 0;
    }

    function getPrevUser(address _address,uint256 _tokenId) view internal returns(uint256){
        uint256 current_Token = FIRST_TOKEN;
        while(NFTs[_address][current_Token]!=FIRST_TOKEN){
            if(NFTs[_address][current_Token]==_tokenId) return current_Token;
            else current_Token = NFTs[_address][current_Token];
        }
        return FIRST_TOKEN;
    }

    function getallUsers (address _address) view public returns(uint256[] memory){
        uint256 [] memory allUsers = new uint256 [](balanceOf(_address));
        uint256 currentToken = NFTs[_address][FIRST_TOKEN];
        for (uint256 index = 0; currentToken != FIRST_TOKEN; index++) {
            allUsers[index] = currentToken;
            currentToken = NFTs[_address][currentToken];
        }
        return allUsers;
    }
    


}
