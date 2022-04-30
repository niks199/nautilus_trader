# Warning, this file is autogenerated by cbindgen. Don't modify this manually. */

from libc.stdint cimport uint8_t, uint16_t, uint64_t, int64_t
from nautilus_trader.core.rust.core cimport Buffer16, Buffer32, Buffer36, Buffer64, Buffer128, Timestamp

cdef extern from "../includes/model.h":

    const uint8_t FIXED_PRECISION # = 9

    const double FIXED_SCALAR # = 1000000000.0

    cdef enum BookLevel:
        L1_TBBO # = 1,
        L2_MBP # = 2,
        L3_MBO # = 3,

    cdef enum CurrencyType:
        Crypto,
        Fiat,

    cdef enum OrderSide:
        Buy # = 1,
        Sell # = 2,

    cdef struct BTreeMap_BookPrice__Level:
        pass

    cdef struct HashMap_u64__BookPrice:
        pass

    cdef struct Symbol:
        Buffer128 value;

    cdef struct Venue:
        Buffer16 value;

    cdef struct InstrumentId_t:
        Symbol symbol;
        Venue venue;

    cdef struct Price_t:
        int64_t raw;
        uint8_t precision;

    cdef struct Quantity_t:
        uint64_t raw;
        uint8_t precision;

    # Represents a single quote tick in a financial market.
    cdef struct QuoteTick_t:
        InstrumentId_t instrument_id;
        Price_t bid;
        Price_t ask;
        Quantity_t bid_size;
        Quantity_t ask_size;
        Timestamp ts_event;
        Timestamp ts_init;

    cdef struct TradeId_t:
        Buffer64 value;

    # Represents a single trade tick in a financial market.
    cdef struct TradeTick_t:
        InstrumentId_t instrument_id;
        Price_t price;
        Quantity_t size;
        OrderSide aggressor_side;
        TradeId_t trade_id;
        Timestamp ts_event;
        Timestamp ts_init;

    cdef struct Ladder:
        OrderSide side;
        BTreeMap_BookPrice__Level *levels;
        HashMap_u64__BookPrice *cache;

    cdef struct OrderBook:
        Ladder bids;
        Ladder asks;
        InstrumentId_t instrument_id;
        BookLevel book_level;
        OrderSide last_side;
        int64_t ts_last;

    cdef struct Currency_t:
        Buffer16 code;
        uint8_t precision;
        uint16_t iso4217;
        Buffer32 name;
        CurrencyType currency_type;

    cdef struct Money_t:
        int64_t raw;
        Currency_t currency;

    void quote_tick_free(QuoteTick_t tick);

    QuoteTick_t quote_tick_new(InstrumentId_t instrument_id,
                               Price_t bid,
                               Price_t ask,
                               Quantity_t bid_size,
                               Quantity_t ask_size,
                               int64_t ts_event,
                               int64_t ts_init);

    QuoteTick_t quote_tick_from_raw(InstrumentId_t instrument_id,
                                    int64_t bid,
                                    int64_t ask,
                                    uint8_t price_prec,
                                    uint64_t bid_size,
                                    uint64_t ask_size,
                                    uint8_t size_prec,
                                    int64_t ts_event,
                                    int64_t ts_init);

    void trade_tick_free(TradeTick_t tick);

    TradeTick_t trade_tick_from_raw(InstrumentId_t instrument_id,
                                    int64_t price,
                                    uint8_t price_prec,
                                    uint64_t size,
                                    uint8_t size_prec,
                                    OrderSide aggressor_side,
                                    TradeId_t trade_id,
                                    int64_t ts_event,
                                    int64_t ts_init);

    void instrument_id_free(InstrumentId_t instrument_id);

    InstrumentId_t instrument_id_from_buffers(Buffer128 symbol, Buffer16 venue);

    void symbol_free(Symbol symbol);

    Symbol symbol_from_bytes(Buffer128 value);

    Buffer128 symbol_to_bytes(Symbol symbol);

    void trade_id_free(TradeId_t trade_id);

    TradeId_t trade_id_from_buffer(Buffer64 value);

    void venue_free(Venue venue);

    Venue venue_from_bytes(Buffer16 value);

    Buffer16 venue_to_bytes(Venue venue);

    OrderBook order_book_new(InstrumentId_t instrument_id, BookLevel book_level);

    Currency_t currency_new(Buffer16 code,
                            uint8_t precision,
                            uint16_t iso4217,
                            Buffer32 name,
                            CurrencyType currency_type);

    void currency_free(Currency_t currency);

    Money_t money_new(double amount, Currency_t currency);

    Money_t money_from_raw(int64_t raw, Currency_t currency);

    void money_free(Money_t money);

    double money_as_f64(const Money_t *money);

    void money_add_assign(Money_t a, Money_t b);

    void money_sub_assign(Money_t a, Money_t b);

    Price_t price_new(double value, uint8_t precision);

    Price_t price_from_raw(int64_t raw, uint8_t precision);

    void price_free(Price_t price);

    double price_as_f64(const Price_t *price);

    void price_add_assign(Price_t a, Price_t b);

    void price_sub_assign(Price_t a, Price_t b);

    Quantity_t quantity_new(double value, uint8_t precision);

    Quantity_t quantity_from_raw(uint64_t raw, uint8_t precision);

    void quantity_free(Quantity_t qty);

    double quantity_as_f64(const Quantity_t *qty);

    void quantity_add_assign(Quantity_t a, Quantity_t b);

    void quantity_add_assign_u64(Quantity_t a, uint64_t b);

    void quantity_sub_assign(Quantity_t a, Quantity_t b);

    void quantity_sub_assign_u64(Quantity_t a, uint64_t b);