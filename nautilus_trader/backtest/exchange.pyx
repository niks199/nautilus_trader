# -------------------------------------------------------------------------------------------------
#  Copyright (C) 2015-2021 Nautech Systems Pty Ltd. All rights reserved.
#  https://nautechsystems.io
#
#  Licensed under the GNU Lesser General Public License Version 3.0 (the "License");
#  You may not use this file except in compliance with the License.
#  You may obtain a copy of the License at https://www.gnu.org/licenses/lgpl-3.0.en.html
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# -------------------------------------------------------------------------------------------------

from decimal import Decimal
from typing import Dict

from libc.limits cimport INT_MAX
from libc.limits cimport INT_MIN
from libc.stdint cimport int64_t

from nautilus_trader.accounting.accounts.base cimport Account
from nautilus_trader.backtest.execution_client cimport BacktestExecClient
from nautilus_trader.backtest.models cimport FillModel
from nautilus_trader.backtest.modules cimport SimulationModule
from nautilus_trader.cache.base cimport CacheFacade
from nautilus_trader.common.clock cimport TestClock
from nautilus_trader.common.logging cimport Logger
from nautilus_trader.common.queue cimport Queue
from nautilus_trader.common.uuid cimport UUIDFactory
from nautilus_trader.core.correctness cimport Condition
from nautilus_trader.model.c_enums.account_type cimport AccountType
from nautilus_trader.model.c_enums.account_type cimport AccountTypeParser
from nautilus_trader.model.c_enums.book_type cimport BookType
from nautilus_trader.model.c_enums.contingency_type cimport ContingencyType
from nautilus_trader.model.c_enums.depth_type cimport DepthType
from nautilus_trader.model.c_enums.liquidity_side cimport LiquiditySide
from nautilus_trader.model.c_enums.oms_type cimport OMSType
from nautilus_trader.model.c_enums.oms_type cimport OMSTypeParser
from nautilus_trader.model.c_enums.order_side cimport OrderSide
from nautilus_trader.model.c_enums.order_status cimport OrderStatus
from nautilus_trader.model.c_enums.order_type cimport OrderType
from nautilus_trader.model.c_enums.venue_type cimport VenueType
from nautilus_trader.model.c_enums.venue_type cimport VenueTypeParser
from nautilus_trader.model.commands.trading cimport CancelOrder
from nautilus_trader.model.commands.trading cimport ModifyOrder
from nautilus_trader.model.commands.trading cimport SubmitOrder
from nautilus_trader.model.commands.trading cimport SubmitOrderList
from nautilus_trader.model.commands.trading cimport TradingCommand
from nautilus_trader.model.data.tick cimport Tick
from nautilus_trader.model.identifiers cimport ClientOrderId
from nautilus_trader.model.identifiers cimport ExecutionId
from nautilus_trader.model.identifiers cimport InstrumentId
from nautilus_trader.model.identifiers cimport PositionId
from nautilus_trader.model.identifiers cimport StrategyId
from nautilus_trader.model.identifiers cimport Venue
from nautilus_trader.model.identifiers cimport VenueOrderId
from nautilus_trader.model.instruments.base cimport Instrument
from nautilus_trader.model.objects cimport AccountBalance
from nautilus_trader.model.objects cimport Money
from nautilus_trader.model.objects cimport Price
from nautilus_trader.model.objects cimport Quantity
from nautilus_trader.model.orderbook.book cimport OrderBook
from nautilus_trader.model.orderbook.data cimport Order as OrderBookOrder
from nautilus_trader.model.orders.base cimport PassiveOrder
from nautilus_trader.model.orders.limit cimport LimitOrder
from nautilus_trader.model.orders.market cimport MarketOrder
from nautilus_trader.model.orders.stop_limit cimport StopLimitOrder
from nautilus_trader.model.orders.stop_market cimport StopMarketOrder
from nautilus_trader.model.position cimport Position


cdef class SimulatedExchange:
    """
    Provides a simulated financial market exchange.
    """

    def __init__(
        self,
        Venue venue not None,
        VenueType venue_type,
        OMSType oms_type,
        AccountType account_type,
        Currency base_currency,  # Can be None
        list starting_balances not None,
        default_leverage not None: Decimal,
        leverages not None: Dict[InstrumentId, Decimal],
        bint is_frozen_account,
        list instruments not None,
        list modules not None,
        CacheFacade cache not None,
        FillModel fill_model not None,
        TestClock clock not None,
        Logger logger not None,
        BookType book_type=BookType.L1_TBBO,
        bint bar_execution=False,
        bint reject_stop_orders=True,
    ):
        """
        Initialize a new instance of the ``SimulatedExchange`` class.

        Parameters
        ----------
        venue : Venue
            The venue to simulate.
        venue_type : VenueType
            The venues type.
        oms_type : OMSType {``HEDGING``, ``NETTING``}
            The order management system type used by the exchange.
        account_type : AccountType
            The account type for the client.
        base_currency : Currency, optional
            The account base currency for the client. Use ``None`` for multi-currency accounts.
        starting_balances : list[Money]
            The starting balances for the exchange.
        default_leverage : Decimal
            The account default leverage (for margin accounts).
        leverages : Dict[InstrumentId, Decimal]
            The instrument specific leverage configuration (for margin accounts).
        is_frozen_account : bool
            If the account for this exchange is frozen (balances will not change).
        cache : CacheFacade
            The read-only cache for the exchange.
        fill_model : FillModel
            The fill model for the exchange.
        clock : TestClock
            The clock for the exchange.
        logger : Logger
            The logger for the exchange.
        book_type : BookType
            The order book type for the exchange.
        bar_execution : bool
            If the exchange execution dynamics is based on bar data.
        reject_stop_orders : bool
            If stop orders are rejected on submission if in the market.

        Raises
        ------
        ValueError
            If instruments is empty.
        ValueError
            If instruments contains a type other than `Instrument`.
        ValueError
            If starting_balances is empty.
        ValueError
            If starting_balances contains a type other than `Money`.
        ValueError
            If base currency and multiple starting balances.
        ValueError
            If modules contains a type other than `SimulationModule`.

        """
        Condition.not_empty(instruments, "instruments")
        Condition.list_type(instruments, Instrument, "instruments", "Instrument")
        Condition.not_empty(starting_balances, "starting_balances")
        Condition.list_type(starting_balances, Money, "starting_balances")
        Condition.list_type(modules, SimulationModule, "modules", "SimulationModule")
        if base_currency:
            Condition.true(len(starting_balances) == 1, "single-currency account has multiple starting currencies")

        self._clock = clock
        self._uuid_factory = UUIDFactory()
        self._log = LoggerAdapter(
            component_name=f"{type(self).__name__}({venue})",
            logger=logger,
        )

        self.id = venue
        self.venue_type = venue_type
        self.oms_type = oms_type
        self._log.info(f"OMSType={OMSTypeParser.to_str(oms_type)}")
        self.book_type = book_type

        self.cache = cache
        self.exec_client = None  # Initialized when execution client registered

        # Accounting
        self.account_type = account_type
        self.base_currency = base_currency
        self.starting_balances = starting_balances
        self.default_leverage = default_leverage
        self.leverages = leverages
        self.is_frozen_account = is_frozen_account

        # Execution
        self.reject_stop_orders = reject_stop_orders
        self.bar_execution = bar_execution
        self.fill_model = fill_model

        # Load modules
        self.modules = []
        for module in modules:
            Condition.not_in(module, self.modules, "module", "self._modules")
            module.register_exchange(self)
            self.modules.append(module)
            self._log.info(f"Loaded {module}.")

        # InstrumentId indexer for venue_order_ids
        self._instrument_indexer = {}  # type: dict[InstrumentId, int]

        # Load instruments
        self.instruments = {}
        for instrument in instruments:
            Condition.equal(instrument.venue, self.id, "instrument.venue", "self.id")
            self.instruments[instrument.id] = instrument
            index = len(self._instrument_indexer) + 1
            self._instrument_indexer[instrument.id] = index
            self._log.info(f"Loaded instrument {instrument.id.value}.")

        # Markets
        self._books = {}        # type: dict[InstrumentId, OrderBook]
        self._last_bids = {}    # type: dict[InstrumentId, Price]
        self._last_asks = {}    # type: dict[InstrumentId, Price]
        self._order_index = {}  # type: dict[ClientOrderId, PassiveOrder]
        self._orders_bid = {}   # type: dict[InstrumentId, list[PassiveOrder]]
        self._orders_ask = {}   # type: dict[InstrumentId, list[PassiveOrder]]
        self._oto_orders = {}   # type: dict[ClientOrderId]

        self._symbol_pos_count = {}  # type: dict[InstrumentId, int]
        self._symbol_ord_count = {}  # type: dict[InstrumentId, int]
        self._executions_count = 0
        self._message_queue = Queue()

    def __repr__(self) -> str:
        return (f"{type(self).__name__}("
                f"id={self.id}, "
                f"venue_type={VenueTypeParser.to_str(self.venue_type)}, "
                f"oms_type={OMSTypeParser.to_str(self.oms_type)}, "
                f"account_type={AccountTypeParser.to_str(self.account_type)})")

    cpdef Price best_bid_price(self, InstrumentId instrument_id):
        """
        Return the best bid price for the given instrument ID (if found).

        Parameters
        ----------
        instrument_id : InstrumentId
            The instrument ID for the price.

        Returns
        -------
        Price or ``None``

        """
        Condition.not_none(instrument_id, "instrument_id")

        cdef OrderBook order_book = self._books.get(instrument_id)
        if order_book is None:
            return None
        best_bid_price = order_book.best_bid_price()
        if best_bid_price is None:
            return None
        return Price(best_bid_price, order_book.price_precision)

    cpdef Price best_ask_price(self, InstrumentId instrument_id):
        """
        Return the best ask price for the given instrument ID (if found).

        Parameters
        ----------
        instrument_id : InstrumentId
            The instrument ID for the price.

        Returns
        -------
        Price or ``None``

        """
        Condition.not_none(instrument_id, "instrument_id")

        cdef OrderBook order_book = self._books.get(instrument_id)
        if order_book is None:
            return None
        best_ask_price = order_book.best_ask_price()
        if best_ask_price is None:
            return None
        return Price(best_ask_price, order_book.price_precision)

    cpdef OrderBook get_book(self, InstrumentId instrument_id):
        """
        Return the order book for the given instrument ID.

        Parameters
        ----------
        instrument_id : InstrumentId
            The instrument ID for the price.

        Returns
        -------
        OrderBook

        """
        Condition.not_none(instrument_id, "instrument_id")

        cdef OrderBook book = self._books.get(instrument_id)
        if book is None:
            instrument = self.instruments.get(instrument_id)
            if instrument is None:
                raise RuntimeError(
                    f"cannot create OrderBook: no instrument for {instrument_id.value}"
                )
            # Create order book
            book = OrderBook.create(
                instrument=instrument,
                book_type=self.book_type,
                simulated=True,
            )

            # Add to books
            self._books[instrument_id] = book

        return book

    cpdef dict get_books(self):
        """
        Return all order books with the exchange.

        Returns
        -------
        dict[InstrumentId, OrderBook]

        """
        return self._books.copy()

    cpdef list get_working_orders(self, InstrumentId instrument_id=None):
        """
        Return the working orders at the exchange.

        Parameters
        ----------
        instrument_id : InstrumentId, optional
            The instrument_id query filter.

        Returns
        -------
        list[Passive]

        """
        return (
            self.get_working_bid_orders(instrument_id)
            + self.get_working_ask_orders(instrument_id)
        )

    cpdef list get_working_bid_orders(self, InstrumentId instrument_id=None):
        """
        Return the working bid orders at the exchange.

        Parameters
        ----------
        instrument_id : InstrumentId, optional
            The instrument_id query filter.

        Returns
        -------
        list[Passive]

        """
        cdef list bids = []
        if instrument_id is None:
            for orders in self._orders_bid.values():
                for o in orders:
                    bids.append(o)
            return bids
        else:
            return [o for o in self._orders_bid.get(instrument_id, [])]

    cpdef list get_working_ask_orders(self, InstrumentId instrument_id=None):
        """
        Return the working ask orders at the exchange.

        Parameters
        ----------
        instrument_id : InstrumentId, optional
            The instrument_id query filter.

        Returns
        -------
        list[Passive]

        """
        cdef list asks = []
        if instrument_id is None:
            for orders in self._orders_ask.values():
                for o in orders:
                    asks.append(o)
            return asks
        else:
            return [o for o in self._orders_ask.get(instrument_id, [])]

    cpdef Account get_account(self):
        """
        Return the account for the registered client (if registered).

        Returns
        -------
        Account or ``None``

        """
        if not self.exec_client:
            return None

        return self.exec_client.get_account()

    cpdef void register_client(self, BacktestExecClient client) except *:
        """
        Register the given execution client with the simulated exchange.

        Parameters
        ----------
        client : BacktestExecClient
            The client to register

        """
        Condition.not_none(client, "client")

        self.exec_client = client

        self._log.info(f"Registered ExecutionClient {client}.")

    cpdef void set_fill_model(self, FillModel fill_model) except *:
        """
        Set the fill model to the given model.

        fill_model : FillModel
            The fill model to set.

        """
        Condition.not_none(fill_model, "fill_model")

        self.fill_model = fill_model

        self._log.info("Changed fill model.")

    cpdef void initialize_account(self) except *:
        """
        Initialize the account to the starting balances.
        """
        self._generate_fresh_account_state()

    cpdef void adjust_account(self, Money adjustment) except *:
        """
        Adjust the account at the exchange with the given adjustment.

        Parameters
        ----------
        adjustment : Money
            The adjustment for the account.

        """
        Condition.not_none(adjustment, "adjustment")

        if self.is_frozen_account:
            return  # Nothing to adjust

        account = self.cache.account_for_venue(self.exec_client.venue)
        if account is None:
            self._log.error(
                f"Cannot adjust account: no account found for {self.exec_client.venue}"
            )
            return

        cdef AccountBalance balance = account.balance(adjustment.currency)
        if balance is None:
            self._log.error(
                f"Cannot adjust account: no balance found for {adjustment.currency}"
            )
            return

        balance.total = Money(balance.total + adjustment, adjustment.currency)
        balance.free = Money(balance.free + adjustment, adjustment.currency)

        # Generate and handle event
        self.exec_client.generate_account_state(
            balances=[balance],
            reported=True,
            ts_event=self._clock.timestamp_ns(),
        )

    cpdef void send(self, TradingCommand command) except *:
        """
        Send the given trading command into the exchange.

        Parameters
        ----------
        command : TradingCommand
            The command to send.

        """
        Condition.not_none(command, "command")

        self._message_queue.put_nowait(command)

    cpdef void process_order_book(self, OrderBookData data) except *:
        """
        Process the exchanges market for the given order book data.

        Parameters
        ----------
        data : OrderBookData
            The order book data to process.

        """
        Condition.not_none(data, "data")

        self._clock.set_time(data.ts_init)
        self.get_book(data.instrument_id).apply(data)

        self._iterate_matching_engine(
            data.instrument_id,
            data.ts_init,
        )

        if not self._log.is_bypassed:
            self._log.debug(f"Processed {data}")

    cpdef void process_tick(self, Tick tick) except *:
        """
        Process the exchanges market for the given tick.

        Market dynamics are simulated by auctioning working orders.

        Parameters
        ----------
        tick : Tick
            The tick to process.

        """
        Condition.not_none(tick, "tick")

        self._clock.set_time(tick.ts_init)

        cdef OrderBook book = self.get_book(tick.instrument_id)
        if book.type == BookType.L1_TBBO:
            book.update_tick(tick)

        self._iterate_matching_engine(
            tick.instrument_id,
            tick.ts_init,
        )

        if not self._log.is_bypassed:
            self._log.debug(f"Processed {tick}")

    cpdef void process_bar(self, Bar bar) except *:
        """
        Process the exchanges market for the given bar.

        Market dynamics are simulated by auctioning working orders.

        Parameters
        ----------
        bar : Bar
            The tick to process.

        """
        Condition.not_none(bar, "bar")

        self._clock.set_time(bar.ts_init)

        # TODO(cs): Implement simulated order book bar processing
        # cdef OrderBook book = self.get_book(bar.type.instrument_id)
        # if book.level == BookType.L1_TBBO:
        #     book.update_tick(tick)
        #
        # self._iterate_matching_engine(
        #     tick.instrument_id,
        #     tick.ts_init,
        # )

        if not self._log.is_bypassed:
            self._log.debug(f"Processed {bar}")

    cpdef void process(self, int64_t now_ns) except *:
        """
        Process the exchange to the gives time.

        All pending commands will be processed along with all simulation modules.

        Parameters
        ----------
        now_ns : int64
            The UNIX timestamp (nanoseconds) now.

        """
        self._clock.set_time(now_ns)

        cdef:
            TradingCommand command
            Order order
        while self._message_queue.count > 0:
            command = self._message_queue.get_nowait()
            if isinstance(command, SubmitOrder):
                self._process_order(command.order)
            elif isinstance(command, SubmitOrderList):
                for order in command.list.orders:
                    self._process_order(order)
            elif isinstance(command, CancelOrder):
                order = self._order_index.pop(command.client_order_id, None)
                if order is None:
                    self._generate_order_cancel_rejected(
                        command.strategy_id,
                        command.instrument_id,
                        command.client_order_id,
                        command.venue_order_id,
                        f"{repr(command.client_order_id)} not found",
                    )
                    continue
                if order.is_active_c():
                    self._generate_order_pending_cancel(order)
                    self._cancel_order(order)
            elif isinstance(command, ModifyOrder):
                order = self._order_index.get(command.client_order_id)
                if order is None:
                    self._generate_order_modify_rejected(
                        command.strategy_id,
                        command.instrument_id,
                        command.client_order_id,
                        command.venue_order_id,
                        f"{repr(command.client_order_id)} not found",
                    )
                    continue
                self._generate_order_pending_update(order)
                self._update_order(
                    order,
                    command.quantity,
                    command.price,
                    command.trigger,
                )

        # Iterate over modules
        cdef SimulationModule module
        for module in self.modules:
            module.process(now_ns)

        self._last_bids.clear()
        self._last_asks.clear()

    cpdef void reset(self) except *:
        """
        Reset the simulated exchange.

        All stateful fields are reset to their initial value.
        """
        self._log.debug(f"Resetting...")

        for module in self.modules:
            module.reset()

        self._generate_fresh_account_state()

        self._books.clear()
        self._last_bids.clear()
        self._last_asks.clear()
        self._order_index.clear()
        self._orders_bid.clear()
        self._orders_ask.clear()

        self._symbol_pos_count.clear()
        self._symbol_ord_count.clear()
        self._executions_count = 0
        self._message_queue = Queue()

        self._log.info("Reset.")

# -- COMMAND HANDLING ------------------------------------------------------------------------------

    cdef void _process_order(self, Order order) except *:
        if order.client_order_id in self._order_index:
            return  # Already processed

        # Check contingency orders
        cdef ClientOrderId client_order_id
        if order.contingency == ContingencyType.OTO:
            assert order.child_order_ids is not None
            for client_order_id in order.child_order_ids:
                self._oto_orders[client_order_id] = order.client_order_id

        cdef Order parent
        if order.parent_order_id is not None:
            if order.client_order_id in self._oto_orders:
                parent = self.cache.order(order.parent_order_id)
                assert parent is not None, "OTO parent not found"
                if parent.status_c() == OrderStatus.REJECTED and order.is_active_c():
                    self._generate_order_rejected(
                        order,
                        f"REJECT OTO from {parent.client_order_id}",
                    )
                    return  # Order rejected
                elif parent.status_c() == OrderStatus.ACCEPTED:
                    self._log.info(
                        f"Pending OTO {order.client_order_id} "
                        f"triggers from {parent.client_order_id}",
                    )
                    return  # Pending trigger

        # Check reduce-only instruction
        cdef Position position
        if order.is_reduce_only:
            position = self.cache.position_for_order(order.client_order_id)
            if (
                not position
                or position.is_closed_c()
                or (order.is_buy_c() and position.is_long_c())
                or (order.is_sell_c() and position.is_short_c())
            ):
                self._generate_order_rejected(
                    order,
                    f"REDUCE_ONLY {order.type_string_c()} {order.side_string_c()} order "
                    f"would have increased position.",
                )
                return  # Reduce only

        if order.type == OrderType.MARKET:
            self._process_market_order(order)
        elif order.type == OrderType.LIMIT:
            self._process_limit_order(order)
        elif order.type == OrderType.STOP_MARKET:
            self._process_stop_market_order(order)
        elif order.type == OrderType.STOP_LIMIT:
            self._process_stop_limit_order(order)
        else:  # pragma: no cover (design-time error)
            raise RuntimeError("unsupported order type")

    cdef void _process_market_order(self, MarketOrder order) except *:
        # Check market exists
        if order.side == OrderSide.BUY and not self.best_ask_price(order.instrument_id):
            self._generate_order_rejected(order, f"no market for {order.instrument_id}")
            return  # Cannot accept order
        elif order.side == OrderSide.SELL and not self.best_bid_price(order.instrument_id):
            self._generate_order_rejected(order, f"no market for {order.instrument_id}")
            return  # Cannot accept order

        # Immediately fill marketable order
        self._fill_market_order(order, LiquiditySide.TAKER)

    cdef void _process_limit_order(self, LimitOrder order) except *:
        if order.is_post_only and self._is_limit_marketable(order.instrument_id, order.side, order.price):
            self._generate_order_rejected(
                order,
                f"POST_ONLY LIMIT {order.side_string_c()} order "
                f"limit px of {order.price} would have been a TAKER: "
                f"bid={self.best_bid_price(order.instrument_id)}, "
                f"ask={self.best_ask_price(order.instrument_id)}",
            )
            return  # Invalid price

        # Order is valid and accepted
        self._accept_order(order)

        # Check for immediate fill
        if self._is_limit_matched(order.instrument_id, order.side, order.price):
            # Filling as liquidity taker
            self._fill_limit_order(order, LiquiditySide.TAKER)

    cdef void _process_stop_market_order(self, StopMarketOrder order) except *:
        if self._is_stop_marketable(order.instrument_id, order.side, order.price):
            if self.reject_stop_orders:
                self._generate_order_rejected(
                    order,
                    f"STOP {order.side_string_c()} order "
                    f"stop px of {order.price} was in the market: "
                    f"bid={self.best_bid_price(order.instrument_id)}, "
                    f"ask={self.best_ask_price(order.instrument_id)}",
                )
                return  # Invalid price

        # Order is valid and accepted
        self._accept_order(order)

    cdef void _process_stop_limit_order(self, StopLimitOrder order) except *:
        if self._is_stop_marketable(order.instrument_id, order.side, order.trigger):
            self._generate_order_rejected(
                order,
                f"STOP_LIMIT {order.side_string_c()} order "
                f"trigger stop px of {order.trigger} was in the market: "
                f"bid={self.best_bid_price(order.instrument_id)}, "
                f"ask={self.best_ask_price(order.instrument_id)}",
            )
            return  # Invalid price

        # Order is valid and accepted
        self._accept_order(order)

    cdef void _update_limit_order(
        self,
        LimitOrder order,
        Quantity qty,
        Price price,
    ) except *:
        if self._is_limit_marketable(order.instrument_id, order.side, price):
            if order.is_post_only:
                self._generate_order_modify_rejected(
                    order.strategy_id,
                    order.instrument_id,
                    order.client_order_id,
                    order.venue_order_id,
                    f"POST_ONLY LIMIT {order.side_string_c()} order "
                    f"new limit px of {price} would have been a TAKER: "
                    f"bid={self.best_bid_price(order.instrument_id)}, "
                    f"ask={self.best_ask_price(order.instrument_id)}",
                )
                return  # Cannot update order

            self._generate_order_updated(order, qty, price, None)
            self._fill_limit_order(order, LiquiditySide.TAKER)  # Immediate fill as TAKER
            return  # Filled

        self._generate_order_updated(order, qty, price, None)

    cdef void _update_stop_market_order(
        self,
        StopMarketOrder order,
        Quantity qty,
        Price price,
    ) except *:
        if self._is_stop_marketable(order.instrument_id, order.side, price):
            self._generate_order_modify_rejected(
                order.strategy_id,
                order.instrument_id,
                order.client_order_id,
                order.venue_order_id,
                f"STOP {order.side_string_c()} order "
                f"new stop px of {price} was in the market: "
                f"bid={self.best_bid_price(order.instrument_id)}, "
                f"ask={self.best_ask_price(order.instrument_id)}",
            )
            return  # Cannot update order

        self._generate_order_updated(order, qty, price, None)

    cdef void _update_stop_limit_order(
        self,
        StopLimitOrder order,
        Quantity qty,
        Price price,
        Price trigger,
    ) except *:
        if not order.is_triggered:
            # Updating stop price
            if self._is_stop_marketable(order.instrument_id, order.side, price):
                self._generate_order_modify_rejected(
                    order.strategy_id,
                    order.instrument_id,
                    order.client_order_id,
                    order.venue_order_id,
                    f"STOP_LIMIT {order.side_string_c()} order "
                    f"new trigger stop px of {price} was in the market: "
                    f"bid={self.best_bid_price(order.instrument_id)}, "
                    f"ask={self.best_ask_price(order.instrument_id)}",
                )
                return  # Cannot update order
        else:
            # Updating limit price
            if self._is_limit_marketable(order.instrument_id, order.side, price):
                if order.is_post_only:
                    self._generate_order_modify_rejected(
                        order.strategy_id,
                        order.instrument_id,
                        order.client_order_id,
                        order.venue_order_id,
                        f"POST_ONLY LIMIT {order.side_string_c()} order  "
                        f"new limit px of {price} would have been a TAKER: "
                        f"bid={self.best_bid_price(order.instrument_id)}, "
                        f"ask={self.best_ask_price(order.instrument_id)}",
                    )
                    return  # Cannot update order
                else:
                    self._generate_order_updated(order, qty, price, None)
                    self._fill_limit_order(order, LiquiditySide.TAKER)  # Immediate fill as TAKER
                    return  # Filled

        self._generate_order_updated(order, qty, price, trigger or order.trigger)

# -- EVENT HANDLING --------------------------------------------------------------------------------

    cdef void _accept_order(self, PassiveOrder order) except *:
        self._add_order(order)
        self._generate_order_accepted(order)

    cdef void _update_order(self, PassiveOrder order, Quantity qty, Price price, Price trigger=None, bint update_ocos=True) except *:
        if qty is None:
            qty = order.quantity
        if price is None:
            price = order.price

        if order.type == OrderType.LIMIT:
            self._update_limit_order(order, qty, price)
        elif order.type == OrderType.STOP_MARKET:
            self._update_stop_market_order(order, qty, price)
        elif order.type == OrderType.STOP_LIMIT:
            if trigger is None:
                trigger = order.trigger
            self._update_stop_limit_order(order, qty, price, trigger)
        else:  # pragma: no cover (design-time error)
            raise RuntimeError("invalid order type")

        if order.contingency == ContingencyType.OCO and update_ocos:
            self._update_oco_orders(order)

    cdef void _update_oco_orders(self, PassiveOrder order) except *:
        self._log.debug(f"Updating OCO orders from {order.client_order_id}")
        cdef ClientOrderId client_order_id
        cdef PassiveOrder oco_order
        for client_order_id in order.contingency_ids:
            oco_order = self.cache.order(client_order_id)
            assert oco_order is not None, "OCO order not found"
            if oco_order.leaves_qty != order.leaves_qty:
                self._update_order(
                    oco_order,
                    order.leaves_qty,
                    oco_order.price,
                    trigger=None,
                    update_ocos=False,
                )

    cdef void _cancel_order(self, PassiveOrder order, bint cancel_ocos=True) except *:
        if order.venue_order_id is None:
            order.venue_order_id = self._generate_venue_order_id(order.instrument_id)

        cdef:
            list orders_bid
            list orders_ask
        if order.is_buy_c():
            orders_bid = self._orders_bid.get(order.instrument_id)
            if orders_bid and order in orders_bid:
                orders_bid.remove(order)
        elif order.is_sell_c():
            orders_ask = self._orders_ask.get(order.instrument_id)
            if orders_ask and order in orders_ask:
                orders_ask.remove(order)

        self._generate_order_canceled(order)

        cdef ClientOrderId client_order_id
        cdef PassiveOrder oco_order
        if order.contingency == ContingencyType.OCO and cancel_ocos:
            self._cancel_oco_orders(order)

    cdef void _cancel_oco_orders(self, PassiveOrder order) except*:
        self._log.debug(f"Canceling OCO orders from {order.client_order_id}")
        # Iterate all contingency orders and cancel if active
        cdef ClientOrderId client_order_id
        cdef PassiveOrder oco_order
        for client_order_id in order.contingency_ids:
            oco_order = self.cache.order(client_order_id)
            assert oco_order is not None, "OCO order not found"
            if oco_order.is_active_c():
                self._cancel_order(oco_order, cancel_ocos=False)

    cdef void _expire_order(self, PassiveOrder order) except *:
        self._generate_order_expired(order)

        if order.contingency == ContingencyType.OCO:
            self._cancel_oco_orders(order)

# -- ORDER MATCHING ENGINE -------------------------------------------------------------------------

    cdef void _add_order(self, PassiveOrder order) except *:
        # Index order
        self._order_index[order.client_order_id] = order

        if order.is_buy_c():
            orders_bid = self._orders_bid.get(order.instrument_id)
            if orders_bid is None:
                orders_bid = []
                self._orders_bid[order.instrument_id] = orders_bid
            orders_bid.append(order)
            orders_bid.sort(key=lambda x: x.price, reverse=True)
        elif order.is_sell_c():
            orders_ask = self._orders_ask.get(order.instrument_id)
            if orders_ask is None:
                orders_ask = []
                self._orders_ask[order.instrument_id] = orders_ask
            orders_ask.append(order)
            orders_ask.sort(key=lambda x: x.price)

    cdef void _delete_order(self, Order order) except *:
        self._order_index.pop(order.client_order_id, None)

        if order.is_buy_c():
            orders_bid = self._orders_bid.get(order.instrument_id)
            if orders_bid is not None:
                orders_bid.remove(order)
        elif order.is_sell_c():
            orders_ask = self._orders_ask.get(order.instrument_id)
            if orders_ask is not None:
                orders_ask.remove(order)

    cdef void _iterate_matching_engine(
        self, InstrumentId instrument_id,
        int64_t timestamp_ns,
    ) except *:
        # Iterate bids
        cdef list orders_bid = self._orders_bid.get(instrument_id)
        if orders_bid is not None:
            self._iterate_side(orders_bid.copy(), timestamp_ns)  # Copy list for safe loop

        # Iterate asks
        cdef list orders_ask = self._orders_ask.get(instrument_id)
        if orders_ask is not None:
            self._iterate_side(orders_ask.copy(), timestamp_ns)  # Copy list for safe loop

    cdef void _iterate_side(self, list orders, int64_t timestamp_ns) except *:
        cdef PassiveOrder order
        for order in orders:
            if not order.is_working_c():
                continue  # Orders state has changed since the loop started
            elif order.expire_time and timestamp_ns >= order.expire_time_ns:
                self._delete_order(order)
                self._expire_order(order)
                continue
            # Check for order match
            self._match_order(order)

    cdef void _match_order(self, PassiveOrder order) except *:
        if order.type == OrderType.LIMIT:
            self._match_limit_order(order)
        elif order.type == OrderType.STOP_MARKET:
            self._match_stop_market_order(order)
        elif order.type == OrderType.STOP_LIMIT:
            self._match_stop_limit_order(order)
        else:  # pragma: no cover (design-time error)
            raise RuntimeError("invalid order type")

    cdef void _match_limit_order(self, LimitOrder order) except *:
        if self._is_limit_matched(order.instrument_id, order.side, order.price):
            self._fill_limit_order(order, LiquiditySide.MAKER)

    cdef void _match_stop_market_order(self, StopMarketOrder order) except *:
        if self._is_stop_triggered(order.instrument_id, order.side, order.price):
            # Triggered stop places market order
            self._fill_market_order(order, LiquiditySide.TAKER)

    cdef void _match_stop_limit_order(self, StopLimitOrder order) except *:
        if order.is_triggered:
            if self._is_limit_matched(order.instrument_id, order.side, order.price):
                self._fill_limit_order(order, LiquiditySide.MAKER)
            return

        if self._is_stop_triggered(order.instrument_id, order.side, order.trigger):
            self._generate_order_triggered(order)
            # Check for immediate fill
            if not self._is_limit_marketable(order.instrument_id, order.side, order.price):
                return

            if order.is_post_only:  # Would be liquidity taker
                self._delete_order(order)  # Remove order from working orders
                self._generate_order_rejected(
                    order,
                    f"POST_ONLY LIMIT {order.side_string_c()} order "
                    f"limit px of {order.price} would have been a TAKER: "
                    f"bid={self.best_bid_price(order.instrument_id)}, "
                    f"ask={self.best_ask_price(order.instrument_id)}",
                )
            else:
                self._fill_limit_order(order, LiquiditySide.TAKER)  # Fills as TAKER

    cdef bint _is_limit_marketable(self, InstrumentId instrument_id, OrderSide side, Price order_price) except *:
        if side == OrderSide.BUY:
            ask = self.best_ask_price(instrument_id)
            if ask is None:
                return False  # No market
            return order_price >= ask  # Match with LIMIT sells
        else:  # => OrderSide.SELL
            bid = self.best_bid_price(instrument_id)
            if bid is None:  # No market
                return False
            return order_price <= bid  # Match with LIMIT buys

    cdef bint _is_limit_matched(self, InstrumentId instrument_id, OrderSide side, Price price) except *:
        if side == OrderSide.BUY:
            ask = self.best_ask_price(instrument_id)
            if ask is None:
                return False  # No market
            return price > ask or (ask == price and self.fill_model.is_limit_filled())
        else:  # => OrderSide.SELL
            bid = self.best_bid_price(instrument_id)
            if bid is None:
                return False  # No market
            return price < bid or (bid == price and self.fill_model.is_limit_filled())

    cdef bint _is_stop_marketable(self, InstrumentId instrument_id, OrderSide side, Price price) except *:
        if side == OrderSide.BUY:
            ask = self.best_ask_price(instrument_id)
            if ask is None:
                return False  # No market
            return ask >= price  # Match with LIMIT sells
        else:  # => OrderSide.SELL
            bid = self.best_bid_price(instrument_id)
            if bid is None:
                return False  # No market
            return bid <= price  # Match with LIMIT buys

    cdef bint _is_stop_triggered(self, InstrumentId instrument_id, OrderSide side, Price price) except *:
        if side == OrderSide.BUY:
            ask = self.best_ask_price(instrument_id)
            if ask is None:
                return False  # No market
            return ask > price or (ask == price and self.fill_model.is_stop_filled())
        elif side == OrderSide.SELL:
            bid = self.best_bid_price(instrument_id)
            if bid is None:
                return False  # No market
            return bid < price or (bid == price and self.fill_model.is_stop_filled())

    cdef list _determine_limit_price_and_volume(self, PassiveOrder order):
        if self.bar_execution:
            if order.is_buy_c():
                self._last_bids[order.instrument_id] = order.price
            elif order.is_sell_c():
                self._last_asks[order.instrument_id] = order.price
            return [(order.price, order.leaves_qty)]
        cdef OrderBook book = self.get_book(order.instrument_id)
        cdef OrderBookOrder submit_order = OrderBookOrder(price=order.price, size=order.quantity, side=order.side)

        if order.is_buy_c():
            return book.asks.simulate_order_fills(order=submit_order, depth_type=DepthType.VOLUME)
        elif order.is_sell_c():
            return book.bids.simulate_order_fills(order=submit_order, depth_type=DepthType.VOLUME)

    cdef list _determine_market_price_and_volume(self, Order order):
        cdef Price price
        if self.bar_execution:
            if order.type == OrderType.MARKET:
                if order.is_buy_c():
                    price = self._last_asks.get(order.instrument_id)
                    if price is not None:
                        return [(price, order.leaves_qty)]
                elif order.is_sell_c():
                    price = self._last_bids.get(order.instrument_id)
                    if price is not None:
                        return [(price, order.leaves_qty)]
            else:
                if order.is_buy_c():
                    self._last_asks[order.instrument_id] = order.price
                elif order.is_sell_c():
                    self._last_bids[order.instrument_id] = order.price
                return [(order.price, order.leaves_qty)]
        price = Price.from_int_c(INT_MAX if order.side == OrderSide.BUY else INT_MIN)
        cdef OrderBookOrder submit_order = OrderBookOrder(price=price, size=order.quantity, side=order.side)
        cdef OrderBook book = self.get_book(order.instrument_id)
        if order.is_buy_c():
            return book.asks.simulate_order_fills(order=submit_order)
        elif order.is_sell_c():
            return book.bids.simulate_order_fills(order=submit_order)

    cdef void _fill_limit_order(self, PassiveOrder order, LiquiditySide liquidity_side) except *:
        cdef PositionId position_id = self._get_position_id(order)
        cdef Position position = None
        if position_id is not None:
            position = self.cache.position(position_id)
        if order.is_reduce_only and position is None:
            self._log.warning(
                f"Canceling REDUCE_ONLY {order.type_string_c()} "
                f"as would increase position.",
            )
            self._cancel_order(order)
            return  # Order canceled

        self._apply_fills(
            order=order,
            liquidity_side=liquidity_side,
            fills=self._determine_limit_price_and_volume(order),
            position_id=position_id,
            position=position,
        )

    cdef void _fill_market_order(self, Order order, LiquiditySide liquidity_side) except *:
        cdef PositionId position_id = self._get_position_id(order)
        cdef Position position = None
        if position_id is not None:
            position = self.cache.position(position_id)
        if order.is_reduce_only and position is None:
            self._log.warning(
                f"Canceling REDUCE_ONLY {order.type_string_c()} "
                f"as would increase position.",
            )
            self._cancel_order(order)
            return  # Order canceled

        self._apply_fills(
            order=order,
            liquidity_side=liquidity_side,
            fills=self._determine_market_price_and_volume(order),
            position_id=position_id,
            position=position,
        )

    cdef void _apply_fills(
        self,
        Order order,
        LiquiditySide liquidity_side,
        list fills,
        PositionId position_id,
        Position position,
    ) except *:
        if not fills:
            return  # No fills

        cdef Instrument instrument = self.instruments[order.instrument_id]

        cdef Price fill_px
        cdef Quantity fill_qty
        for fill_px, fill_qty in fills:
            if order.is_reduce_only and order.leaves_qty == 0:
                return  # Done early
            if order.type == OrderType.STOP_MARKET:
                fill_px = order.price  # TODO: Temporary strategy for market moving through price
            if self.book_type == BookType.L1_TBBO and self.fill_model.is_slipped():
                if order.side == OrderSide.BUY:
                    fill_px = Price(fill_px + instrument.price_increment, instrument.price_precision)
                else:  # => OrderSide.SELL
                    fill_px = Price(fill_px - instrument.price_increment, instrument.price_precision)
            if order.is_reduce_only and fill_qty > position.quantity:
                # Adjust fill to honor reduce only execution
                org_qty: Decimal = fill_qty.as_decimal()
                adj_qty: Decimal = fill_qty - (fill_qty - position.quantity)
                fill_qty = Quantity(adj_qty, fill_qty.precision)
                updated_qty = order.quantity.as_decimal() - (org_qty - adj_qty)
                if updated_qty > 0:
                    self._generate_order_updated(
                        order=order,
                        qty=Quantity(updated_qty, fill_qty.precision),
                        price=None,
                        trigger=None,
                    )
            if fill_qty <= 0:
                return  # Done
            self._fill_order(
                instrument=instrument,
                order=order,
                venue_position_id=position_id,
                position=position,
                last_qty=fill_qty,
                last_px=fill_px,
                liquidity_side=liquidity_side,
            )

        if (
            order.is_working_c()
            and self.book_type == BookType.L1_TBBO
            and (order.type == OrderType.MARKET or order.type == OrderType.STOP_MARKET)
        ):
            # Exhausted simulated book volume - continue aggressive filling into next level)
            fill_px = fills[-1][0]
            if order.side == OrderSide.BUY:
                fill_px = Price(fill_px + instrument.price_increment, instrument.price_precision)
            else:  # => OrderSide.SELL
                fill_px = Price(fill_px - instrument.price_increment, instrument.price_precision)
            self._fill_order(
                instrument=instrument,
                order=order,
                venue_position_id=position_id,
                position=position,
                last_qty=order.leaves_qty,
                last_px=fill_px,
                liquidity_side=liquidity_side,
            )

    cdef void _fill_order(
        self,
        Instrument instrument,
        Order order,
        PositionId venue_position_id,
        Position position,  # Can be None
        Quantity last_qty,
        Price last_px,
        LiquiditySide liquidity_side,
    ) except *:
        # Calculate commission
        cdef Money commission = self.exec_client.get_account().calculate_commission(
            instrument=instrument,
            last_qty=order.quantity,
            last_px=last_px,
            liquidity_side=liquidity_side,
        )

        self._generate_order_filled(
            order=order,
            venue_position_id=venue_position_id,
            last_qty=last_qty,
            last_px=last_px,
            quote_currency=instrument.quote_currency,
            commission=commission,
            liquidity_side=liquidity_side,
        )

        if order.is_passive_c() and order.is_completed_c():
            # Remove order from market
            self._delete_order(order)

        # Check contingency orders
        cdef ClientOrderId client_order_id
        cdef PassiveOrder child_order
        if order.contingency == ContingencyType.OTO:
            for client_order_id in order.child_order_ids:
                child_order = self.cache.order(client_order_id)
                assert child_order is not None, "OTO child order not found"
                if child_order.position_id is None:
                    self.cache.add_position_id(
                        position_id=order.position_id,
                        venue=self.id,
                        client_order_id=client_order_id,
                        strategy_id=child_order.strategy_id,
                    )
                    self._log.debug(
                        f"Indexed {repr(order.position_id)} "
                        f"for {repr(child_order.client_order_id)}",
                    )
                if not child_order.is_working_c():
                    self._accept_order(child_order)
        elif order.contingency == ContingencyType.OCO:
            for client_order_id in order.contingency_ids:
                oco_order = self.cache.order(client_order_id)
                assert oco_order is not None, "OCO order not found"
                if order.is_completed_c() and oco_order.is_active_c():
                    self._cancel_order(oco_order)
                elif order.leaves_qty != oco_order.leaves_qty:
                    self._update_order(
                        oco_order,
                        order.leaves_qty,
                        oco_order.price,
                        trigger=None,
                        update_ocos=False,
                    )

        if position is None:
            return

        # Check reduce only orders for position
        for order in self.cache.orders_for_position(venue_position_id):
            if (
                order.is_reduce_only
                and order.is_active_c()
                and order.is_passive_c()
            ):
                if position.quantity == 0:
                    self._cancel_order(order)
                elif order.leaves_qty != position.quantity:
                    self._update_order(order, position.quantity, order.price)

# -- IDENTIFIER GENERATORS -------------------------------------------------------------------------

    cdef PositionId _get_position_id(self, Order order, bint generate=True):
        cdef PositionId position_id
        if OMSType.HEDGING:
            position_id = self.cache.position_id(order.client_order_id)
            if position_id is not None:
                return position_id
            if generate:
                # Generate a venue position ID
                return self._generate_venue_position_id(order.instrument_id)
        ####################################################################
        # NETTING OMS (position ID will be `{instrument_id}-{strategy_id}`)
        ####################################################################
        cdef list positions_open = self.cache.positions_open(
            venue=None,  # Faster query filtering
            instrument_id=order.instrument_id,
        )
        if positions_open:
            return positions_open[0].id
        else:
            return None

    cdef PositionId _generate_venue_position_id(self, InstrumentId instrument_id):
        cdef int pos_count = self._symbol_pos_count.get(instrument_id, 0)
        pos_count += 1
        self._symbol_pos_count[instrument_id] = pos_count
        return PositionId(f"{self._instrument_indexer[instrument_id]}-{pos_count:03d}")

    cdef VenueOrderId _generate_venue_order_id(self, InstrumentId instrument_id):
        cdef int ord_count = self._symbol_ord_count.get(instrument_id, 0)
        ord_count += 1
        self._symbol_ord_count[instrument_id] = ord_count
        return VenueOrderId(f"{self._instrument_indexer[instrument_id]}-{ord_count:03d}")

    cdef ExecutionId _generate_execution_id(self):
        self._executions_count += 1
        return ExecutionId(f"{self._executions_count}")

# -- EVENT GENERATORS ------------------------------------------------------------------------------

    cdef void _generate_fresh_account_state(self) except *:
        cdef list balances = [
            AccountBalance(
                currency=money.currency,
                total=money,
                locked=Money(0, money.currency),
                free=money,
            )
            for money in self.starting_balances
        ]

        self.exec_client.generate_account_state(
            balances=balances,
            reported=True,
            ts_event=self._clock.timestamp_ns(),
        )

        # Set leverages
        cdef Account account = self.get_account()
        if account.is_margin_account():
            account.set_default_leverage(self.default_leverage)
            # Set instrument specific leverages
            for instrument_id, leverage in self.leverages.items():
                account.set_leverage(instrument_id, leverage)

    cdef void _generate_order_submitted(self, Order order) except *:
        self.exec_client.generate_order_submitted(
            strategy_id=order.strategy_id,
            instrument_id=order.instrument_id,
            client_order_id=order.client_order_id,
            ts_event=self._clock.timestamp_ns(),
        )

    cdef void _generate_order_rejected(self, Order order, str reason) except *:
        self.exec_client.generate_order_rejected(
            strategy_id=order.strategy_id,
            instrument_id=order.instrument_id,
            client_order_id=order.client_order_id,
            reason=reason,
            ts_event=self._clock.timestamp_ns(),
        )

    cdef void _generate_order_accepted(self, Order order) except *:
        self.exec_client.generate_order_accepted(
            strategy_id=order.strategy_id,
            instrument_id=order.instrument_id,
            client_order_id=order.client_order_id,
            venue_order_id=self._generate_venue_order_id(order.instrument_id),
            ts_event=self._clock.timestamp_ns(),
        )

    cdef void _generate_order_pending_update(self, Order order) except *:
        self.exec_client.generate_order_pending_update(
            strategy_id=order.strategy_id,
            instrument_id=order.instrument_id,
            client_order_id=order.client_order_id,
            venue_order_id=order.venue_order_id,
            ts_event=self._clock.timestamp_ns(),
        )

    cdef void _generate_order_pending_cancel(self, Order order) except *:
        self.exec_client.generate_order_pending_cancel(
            strategy_id=order.strategy_id,
            instrument_id=order.instrument_id,
            client_order_id=order.client_order_id,
            venue_order_id=order.venue_order_id,
            ts_event=self._clock.timestamp_ns(),
        )

    cdef void _generate_order_modify_rejected(
        self,
        StrategyId strategy_id,
        InstrumentId instrument_id,
        ClientOrderId client_order_id,
        VenueOrderId venue_order_id,
        str reason,
    ) except *:
        self.exec_client.generate_order_modify_rejected(
            strategy_id=strategy_id,
            instrument_id=instrument_id,
            client_order_id=client_order_id,
            venue_order_id=venue_order_id,
            reason=reason,
            ts_event=self._clock.timestamp_ns(),
        )

    cdef void _generate_order_cancel_rejected(
        self,
        StrategyId strategy_id,
        InstrumentId instrument_id,
        ClientOrderId client_order_id,
        VenueOrderId venue_order_id,
        str reason,
    ) except *:
        self.exec_client.generate_order_cancel_rejected(
            strategy_id=strategy_id,
            instrument_id=instrument_id,
            client_order_id=client_order_id,
            venue_order_id=venue_order_id,
            reason=reason,
            ts_event=self._clock.timestamp_ns(),
        )

    cdef void _generate_order_updated(
        self,
        Order order,
        Quantity qty,
        Price price,
        Price trigger,
    ) except *:
        cdef VenueOrderId venue_order_id = order.venue_order_id
        cdef bint venue_order_id_modified = False
        if venue_order_id is None:
            venue_order_id = self._generate_venue_order_id(order.instrument_id)
            venue_order_id_modified = True
        # Generate event
        self.exec_client.generate_order_updated(
            strategy_id=order.strategy_id,
            instrument_id=order.instrument_id,
            client_order_id=order.client_order_id,
            venue_order_id=venue_order_id,
            quantity=qty,
            price=price,
            trigger=trigger,
            ts_event=self._clock.timestamp_ns(),
            venue_order_id_modified=venue_order_id_modified,
        )

    cdef void _generate_order_canceled(self, Order order) except *:
        self.exec_client.generate_order_canceled(
            strategy_id=order.strategy_id,
            instrument_id=order.instrument_id,
            client_order_id=order.client_order_id,
            venue_order_id=order.venue_order_id,
            ts_event=self._clock.timestamp_ns(),
        )

    cdef void _generate_order_triggered(self, StopLimitOrder order) except *:
        self.exec_client.generate_order_triggered(
            strategy_id=order.strategy_id,
            instrument_id=order.instrument_id,
            client_order_id=order.client_order_id,
            venue_order_id=order.venue_order_id,
            ts_event=self._clock.timestamp_ns(),
        )

    cdef void _generate_order_expired(self, PassiveOrder order) except *:
        self.exec_client.generate_order_expired(
            strategy_id=order.strategy_id,
            instrument_id=order.instrument_id,
            client_order_id=order.client_order_id,
            venue_order_id=order.venue_order_id,
            ts_event=order.expire_time_ns,
        )

    cdef void _generate_order_filled(
        self,
        Order order,
        PositionId venue_position_id,
        Quantity last_qty,
        Price last_px,
        Currency quote_currency,
        Money commission,
        LiquiditySide liquidity_side
    ) except *:
        cdef VenueOrderId venue_order_id = order.venue_order_id
        if venue_order_id is None:
            venue_order_id = self._generate_venue_order_id(order.instrument_id)
        self.exec_client.generate_order_filled(
            strategy_id=order.strategy_id,
            instrument_id=order.instrument_id,
            client_order_id=order.client_order_id,
            venue_order_id=venue_order_id,
            venue_position_id=venue_position_id,
            execution_id=self._generate_execution_id(),
            order_side=order.side,
            order_type=order.type,
            last_qty=last_qty,
            last_px=last_px,
            quote_currency=quote_currency,
            commission=commission,
            liquidity_side=liquidity_side,
            ts_event=self._clock.timestamp_ns(),
        )