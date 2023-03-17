// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

interface ERC20Contract{
    function balanceOf(address _owner) external view returns (uint256 balance);
    function transferProxy (address _from, address _to, uint256 _value) external returns(bool);
}

interface ERC721Contract{
    function ownerOf(uint256 _tokenId) external  view returns (address);
    function transferProxy(address _from, address _to, uint256 _tokenId) external;
    function setApprovalForAll(address _operator, bool _approved) external;
    function mint(address _address,uint256 _tokenId) external;
}

contract PROXY{
    address private admin;                                                      // Dirección administradora
    mapping(uint24 => Evento) private events;                                   // Asocia cada ID de evento a sus atributos
    uint24 private nextID;                                                      // ID del siguiente evento
    mapping (uint256 => uint24) public ticketPrice;                            // Asocia a cada ticket en reventa su precio
    mapping(uint24 => mapping(uint256 => uint256)) private ticketsOnsale;       // Asocia a cada evento sus tickets en reventa

    ERC20Contract private erc20;                                                // Dirección del contrato erc20
    ERC721Contract private erc721;                                              // Dirección del contrato
    uint256 constant private FIRST_ADDRESS = 9999999999;

    struct Evento {
        uint24 maxTicket;               // Máximo de entradas del evento.
        uint24 lastTicket;              // Último ticket vendido del evento.
        bool soldOut;                   // Variable que indica que se han vendido todas las entradas
        bool active;                    // Variable que indica si por algún motivo externo el concierto se encuentra desactivado o no
        uint16 defaultPrice;            // Precio base
        uint16 minPrice;                // Precio mínimo de reventa
        uint16 maxPrice;                // Precio máximo de reventa
        string name;                    // Nombre del evento    
    }

    // Eventos
    event NewEvent(Evento _e);
    event EventSoldOut(Evento _e);


    // Modificador para limitar una función al owner unicamente
    modifier onlyOwner {
        require(msg.sender == admin);
        _;
    }

    constructor (){
        admin = msg.sender;
        nextID = 1;
        
    }

    // Modificar la variable administradora del contrato
    function setAdminNFTs(address _admin) public onlyOwner{
        admin = _admin;
    }

    /*  GESTIÓN DE CONTRATOS */
    function modifyErc20(address _address) public onlyOwner{
        erc20 = ERC20Contract(_address);
    }

    function modifyErc721(address _address) public onlyOwner{
        erc721 = ERC721Contract(_address);

    }

    /* GESTIÓN DE EVENTOS */

    // Crea un nuevo evento
    function newEvent(uint24 _maxTicket, uint16 _defaultPrice, uint16 _minPrice, uint16 _maxPrice, string memory _name) public onlyOwner returns(uint24){
        require(_defaultPrice > 0 && _minPrice > 0 && _maxPrice > 0, "Error creating a new event: The price should be more than zero.");
        events[nextID].maxTicket = _maxTicket;
        events[nextID].lastTicket = 0;
        events[nextID].soldOut = false;
        events[nextID].active = true;
        events[nextID].defaultPrice = _defaultPrice;
        events[nextID].minPrice = _minPrice;
        events[nextID].maxPrice = _maxPrice;
        events[nextID].name = _name;
        ticketsOnsale[nextID][FIRST_ADDRESS] = FIRST_ADDRESS;
        //emit newEvent(events[nextID]);
        nextID++;
        
        return nextID-1;
    }

    // Modifica algún parámetro de un evento
    function modifyEvent(uint24 _maxTicket, uint16 _defaultPrice, uint16 _minPrice, uint16 _maxPrice, string memory _name, bool _active, uint24 _id) public onlyOwner{
        require(_defaultPrice > 0 && _minPrice > 0 && _maxPrice > 0, "Error creating a new event: The price should be more than zero.");
        require(events[_id].lastTicket < _maxTicket,"Modify event error: Max tickets value is not valid");
        require(_id < nextID,"Modify event error: that event does not exist.");
        events[_id].maxTicket = _maxTicket;
        events[_id].active = _active;
        events[_id].defaultPrice = _defaultPrice;
        events[_id].minPrice = _minPrice;
        events[_id].maxPrice = _maxPrice;
        events[_id].name = _name;
    }

    // Función para consultar los eventos activos.
     function getActiveEvents(uint24 _index) public view returns (Evento[] memory) {

        //

        //
        
        require(_index < nextID,"GetEvents Error: Index value should be greater than the last eventID.");
        uint256 activeCount = 0;
        for (uint24 i = _index; i < nextID; i++) {
            if (events[i].active == true) {
                activeCount++;
            }
        }
        Evento[] memory activeEvents = new Evento[](activeCount);
        uint256 currentIndex = 0;
        for (uint24 i = _index; i < nextID; i++) {
            if (events[i].active == true) {
                activeEvents[currentIndex] = events[i];
                currentIndex++;
            }
        }
        return activeEvents;
    }

    // A partir de un token te devuelve al evento que pertenece
    function getEventID(uint256 _tokenId)public pure returns(uint24){
        if(_tokenId < 10000000000) return 0;
        else{
            uint256 r = _tokenId / 10**10;
            return uint24(r);
        }
        
    }

    // Comprueba que el precio sea válido.
    function validPrice(uint24 _eventID, uint24 price)public view returns(bool){
        return (events[_eventID].maxPrice >= price && events[_eventID].minPrice <= price);
    }

    /*   Marketplace   */

    // Función para poner un NFT a la venta, unicamente el propietario (No un dirección autorizada)
    function sellNft(uint256 _tokenId, uint16 _price) public {
        require(erc721.ownerOf(_tokenId) == msg.sender,"Error in sale: Token doesn't exists or you aren't the owner.");
        uint24 _eventId = getEventID(_tokenId);
        require(validPrice(_eventId,_price),"Error in sale: The price isn't valid.");
        addToken(_eventId, _tokenId);
        ticketPrice[_tokenId] = _price;
    }



    // Función para quitar un NFT de la venta, unicamente el propietario (No un dirección autorizada)
    function cancelSellNft(uint256 _tokenId) public {
        require(erc721.ownerOf(_tokenId) == msg.sender,"Error in sale: Token doesn't exists or you aren't the owner.");
        uint24 _eventId = getEventID(_tokenId);
        removeToken(_eventId, _tokenId);
        delete ticketPrice[_tokenId];
    }

    // Función para comprar una entrada que se encuentra en reventa.
    function buyToken(uint256 _tokenId, uint256 _price) public {
        uint24 _eventId = getEventID(_tokenId);
        require(_price == ticketPrice[_tokenId],"Buy Error: The price is different");
        require(erc20.balanceOf(msg.sender)>=ticketPrice[_tokenId], "Buy Error: you haven't enough coins.");
        erc20.transferProxy(msg.sender,erc721.ownerOf(_tokenId),ticketPrice[_tokenId]);
        erc721.transferProxy(erc721.ownerOf(_tokenId), msg.sender, _tokenId);
        removeToken(_eventId, _tokenId);
        delete ticketPrice[_tokenId];
    }

    /*  Primera venta de entradas  */
    function buyTicket(uint24 _eventID) public payable 
    {
        require(msg.sender != address(0),"Buy Error: Address 0 ins't valid.");
        require(events[_eventID].active==true,"Buy Error: The event hasn't active or does not exist.");
        require(events[_eventID].soldOut!=true, "Buy Error: all tickets have been sold");
        require(erc20.balanceOf(msg.sender)>=events[_eventID].defaultPrice, "Buy Error: you haven't enough coins.");

        erc20.transferProxy(msg.sender,admin, events[_eventID].defaultPrice);
        uint256 tokenID = events[_eventID].lastTicket;
        tokenID = tokenID + (uint256(_eventID)*10000000000);

        erc721.mint(msg.sender, tokenID);

        events[_eventID].lastTicket++;

        if(events[_eventID].lastTicket == events[_eventID].maxTicket){
            events[_eventID].soldOut = true;
            emit EventSoldOut(events[_eventID]);
        } 

    }

    /* Funciones para gestionar la lista de entradas en reventa */
        function isInList(uint24 _eventID, uint256 _tokenID)internal view returns(bool)
    {
        //Si no está devuelve false, ya que su valor si no existe todavía sera todo 0.
        return ticketsOnsale[_eventID][_tokenID] != 0;
    }

    function addToken(uint24 _eventID, uint256 _tokenID) internal
    {
        require(!isInList(_eventID, _tokenID));
        //el nuevo elemento apuntará al que antes era el segundo
        ticketsOnsale[_eventID][_tokenID] = ticketsOnsale[_eventID][FIRST_ADDRESS];
        //el primer elemento ahora apunta a este nuevo.
        ticketsOnsale[_eventID][FIRST_ADDRESS] = _tokenID;

    }

    function removeToken(uint24 _eventID, uint256 _tokenID) internal {
        require(isInList(_eventID, _tokenID));
        uint256 addprevia = getPrevToken(_eventID, _tokenID);
        ticketsOnsale[_eventID][addprevia] =  ticketsOnsale[_eventID][_tokenID];
        ticketsOnsale[_eventID][_tokenID] = 0;
    }

    function getPrevToken(uint24 _eventID, uint256 _tokenID) view internal returns(uint256){
        uint256 currenToken = FIRST_ADDRESS;
        while(ticketsOnsale[_eventID][currenToken]!=FIRST_ADDRESS){
            if(ticketsOnsale[_eventID][currenToken]==_tokenID) return currenToken;
            else currenToken = ticketsOnsale[_eventID][currenToken];
        }
        return FIRST_ADDRESS;
    }

    function getallTokensEvent (uint24 _eventID )view public returns(uint256[] memory){
        uint256 listSize = 0;
        uint256 currenToken = ticketsOnsale[_eventID][FIRST_ADDRESS];
        for (uint256 index = 0; currenToken != FIRST_ADDRESS; index++) {
            currenToken = ticketsOnsale[_eventID][currenToken];
            listSize++;
        }
        uint256 [] memory allTokens = new uint256 [](listSize);

        currenToken = ticketsOnsale[_eventID][FIRST_ADDRESS];
        for (uint256 index = 0; currenToken != FIRST_ADDRESS; index++) {
            allTokens[index] = currenToken;
            currenToken = ticketsOnsale[_eventID][currenToken];
        }
        return allTokens;
    }

    

}