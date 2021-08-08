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

import pytest

from nautilus_trader.common.clock import TestClock
from nautilus_trader.common.factories import OrderFactory
from nautilus_trader.common.logging import Logger
from nautilus_trader.core.uuid import uuid4
from nautilus_trader.execution.engine import ExecutionEngine
from nautilus_trader.model.currencies import ADA
from nautilus_trader.model.currencies import AUD
from nautilus_trader.model.currencies import BTC
from nautilus_trader.model.currencies import ETH
from nautilus_trader.model.currencies import JPY
from nautilus_trader.model.currencies import USD
from nautilus_trader.model.currencies import USDT
from nautilus_trader.model.enums import AccountType
from nautilus_trader.model.enums import LiquiditySide
from nautilus_trader.model.enums import OrderSide
from nautilus_trader.model.enums import PositionSide
from nautilus_trader.model.events.account import AccountState
from nautilus_trader.model.identifiers import AccountId
from nautilus_trader.model.identifiers import ClientId
from nautilus_trader.model.identifiers import PositionId
from nautilus_trader.model.identifiers import StrategyId
from nautilus_trader.model.identifiers import Venue
from nautilus_trader.model.objects import AccountBalance
from nautilus_trader.model.objects import Money
from nautilus_trader.model.objects import Price
from nautilus_trader.model.objects import Quantity
from nautilus_trader.model.position import Position
from nautilus_trader.msgbus.message_bus import MessageBus
from nautilus_trader.trading.account import CashAccount
from nautilus_trader.trading.portfolio import Portfolio
from tests.test_kit.providers import TestInstrumentProvider
from tests.test_kit.stubs import TestStubs


AUDUSD_SIM = TestInstrumentProvider.default_fx_ccy("AUD/USD")
USDJPY_SIM = TestInstrumentProvider.default_fx_ccy("USD/JPY")
ADABTC_BINANCE = TestInstrumentProvider.adabtc_binance()
BTCUSDT_BINANCE = TestInstrumentProvider.btcusdt_binance()


class TestCashAccount:
    def setup(self):
        # Fixture Setup
        self.clock = TestClock()
        self.logger = Logger(self.clock)

        self.trader_id = TestStubs.trader_id()

        self.order_factory = OrderFactory(
            trader_id=self.trader_id,
            strategy_id=StrategyId("S-001"),
            clock=TestClock(),
        )

        self.msgbus = MessageBus(
            trader_id=self.trader_id,
            clock=self.clock,
            logger=self.logger,
        )

        self.cache = TestStubs.cache()

        self.portfolio = Portfolio(
            msgbus=self.msgbus,
            cache=self.cache,
            clock=self.clock,
            logger=self.logger,
        )

        self.exec_engine = ExecutionEngine(
            msgbus=self.msgbus,
            cache=self.cache,
            clock=self.clock,
            logger=self.logger,
        )

    def test_instantiated_accounts_basic_properties(self):
        # Arrange, Act
        account = TestStubs.cash_account()

        # Assert
        assert account.id == AccountId("SIM", "000")
        assert str(account) == "CashAccount(id=SIM-000, type=CASH, base=USD)"
        assert repr(account) == "CashAccount(id=SIM-000, type=CASH, base=USD)"
        assert isinstance(hash(account), int)
        assert account == account
        assert not account != account

    def test_instantiate_single_asset_cash_account(self):
        # Arrange
        event = AccountState(
            client_id=ClientId("SIM"),
            account_id=AccountId("SIM", "000"),
            account_type=AccountType.CASH,
            base_currency=USD,
            reported=True,
            balances=[
                AccountBalance(
                    USD,
                    Money(1_000_000, USD),
                    Money(0, USD),
                    Money(1_000_000, USD),
                ),
            ],
            info={},
            event_id=uuid4(),
            ts_event=0,
            ts_init=0,
        )

        # Act
        account = CashAccount(event)

        # Assert
        assert account.base_currency == USD
        assert account.last_event == event
        assert account.events == [event]
        assert account.event_count == 1
        assert account.balance_total() == Money(1_000_000, USD)
        assert account.balance_free() == Money(1_000_000, USD)
        assert account.balance_locked() == Money(0, USD)
        assert account.balances_total() == {USD: Money(1_000_000, USD)}
        assert account.balances_free() == {USD: Money(1_000_000, USD)}
        assert account.balances_locked() == {USD: Money(0, USD)}

    def test_instantiate_multi_asset_cash_account(self):
        # Arrange
        event = AccountState(
            client_id=ClientId("SIM"),
            account_id=AccountId("SIM", "000"),
            account_type=AccountType.CASH,
            base_currency=None,  # Multi-currency
            reported=True,
            balances=[
                AccountBalance(
                    BTC,
                    Money(10.00000000, BTC),
                    Money(0.00000000, BTC),
                    Money(10.00000000, BTC),
                ),
                AccountBalance(
                    ETH,
                    Money(20.00000000, ETH),
                    Money(0.00000000, ETH),
                    Money(20.00000000, ETH),
                ),
            ],
            info={},  # No default currency set
            event_id=uuid4(),
            ts_event=0,
            ts_init=0,
        )

        # Act
        account = CashAccount(event)

        # Assert
        assert account.id == AccountId("SIM", "000")
        assert account.base_currency is None
        assert account.last_event == event
        assert account.events == [event]
        assert account.event_count == 1
        assert account.balance_total(BTC) == Money(10.00000000, BTC)
        assert account.balance_total(ETH) == Money(20.00000000, ETH)
        assert account.balance_free(BTC) == Money(10.00000000, BTC)
        assert account.balance_free(ETH) == Money(20.00000000, ETH)
        assert account.balance_locked(BTC) == Money(0.00000000, BTC)
        assert account.balance_locked(ETH) == Money(0.00000000, ETH)
        assert account.balances_total() == {
            BTC: Money(10.00000000, BTC),
            ETH: Money(20.00000000, ETH),
        }
        assert account.balances_free() == {
            BTC: Money(10.00000000, BTC),
            ETH: Money(20.00000000, ETH),
        }
        assert account.balances_locked() == {
            BTC: Money(0.00000000, BTC),
            ETH: Money(0.00000000, ETH),
        }

    def test_apply_given_new_state_event_updates_correctly(self):
        # Arrange
        event1 = AccountState(
            client_id=ClientId("SIM"),
            account_id=AccountId("SIM", "001"),
            account_type=AccountType.CASH,
            base_currency=None,  # Multi-currency
            reported=True,
            balances=[
                AccountBalance(
                    BTC,
                    Money(10.00000000, BTC),
                    Money(0.00000000, BTC),
                    Money(10.00000000, BTC),
                ),
                AccountBalance(
                    ETH,
                    Money(20.00000000, ETH),
                    Money(0.00000000, ETH),
                    Money(20.00000000, ETH),
                ),
            ],
            info={},  # No default currency set
            event_id=uuid4(),
            ts_event=0,
            ts_init=0,
        )

        # Act
        account = CashAccount(event1)

        event2 = AccountState(
            client_id=ClientId("SIM"),
            account_id=AccountId("SIM", "001"),
            account_type=AccountType.CASH,
            base_currency=None,  # Multi-currency
            reported=True,
            balances=[
                AccountBalance(
                    BTC,
                    Money(9.00000000, BTC),
                    Money(0.50000000, BTC),
                    Money(8.50000000, BTC),
                ),
                AccountBalance(
                    ETH,
                    Money(20.00000000, ETH),
                    Money(0.00000000, ETH),
                    Money(20.00000000, ETH),
                ),
            ],
            info={},  # No default currency set
            event_id=uuid4(),
            ts_event=0,
            ts_init=0,
        )

        # Act
        account.apply(event=event2)

        # Assert
        assert account.last_event == event2
        assert account.events == [event1, event2]
        assert account.event_count == 2
        assert account.balance_total(BTC) == Money(9.00000000, BTC)
        assert account.balance_free(BTC) == Money(8.50000000, BTC)
        assert account.balance_locked(BTC) == Money(0.50000000, BTC)
        assert account.balance_total(ETH) == Money(20.00000000, ETH)
        assert account.balance_free(ETH) == Money(20.00000000, ETH)
        assert account.balance_locked(ETH) == Money(0.00000000, ETH)

    def test_calculate_pnls_for_single_currency_cash_account(self):
        # Arrange
        event = AccountState(
            client_id=ClientId("SIM"),
            account_id=AccountId("SIM", "001"),
            account_type=AccountType.CASH,
            base_currency=USD,
            reported=True,
            balances=[
                AccountBalance(
                    USD,
                    Money(1_000_000.00, USD),
                    Money(0.00, USD),
                    Money(1_000_000.00, USD),
                ),
            ],
            info={},  # No default currency set
            event_id=uuid4(),
            ts_event=0,
            ts_init=0,
        )

        account = CashAccount(event)

        order = self.order_factory.market(
            AUDUSD_SIM.id,
            OrderSide.BUY,
            Quantity.from_int(1_000_000),
        )

        fill = TestStubs.event_order_filled(
            order,
            instrument=AUDUSD_SIM,
            position_id=PositionId("P-123456"),
            strategy_id=StrategyId("S-001"),
            last_px=Price.from_str("0.80000"),
        )

        position = Position(AUDUSD_SIM, fill)

        # Act
        result = account.calculate_pnls(
            instrument=AUDUSD_SIM,
            position=position,
            fill=fill,
        )

        # Assert
        assert result == [Money(1000000.00, AUD), Money(-800000.00, USD)]

    def test_calculate_pnls_for_multi_currency_cash_account_btcusdt(self):
        # Arrange
        event = AccountState(
            client_id=ClientId("SIM"),
            account_id=AccountId("SIM", "001"),
            account_type=AccountType.CASH,
            base_currency=None,  # Multi-currency
            reported=True,
            balances=[
                AccountBalance(
                    BTC,
                    Money(10.00000000, BTC),
                    Money(0.00000000, BTC),
                    Money(10.00000000, BTC),
                ),
                AccountBalance(
                    ETH,
                    Money(20.00000000, ETH),
                    Money(0.00000000, ETH),
                    Money(20.00000000, ETH),
                ),
            ],
            info={},  # No default currency set
            event_id=uuid4(),
            ts_event=0,
            ts_init=0,
        )

        account = CashAccount(event)

        order = self.order_factory.market(
            BTCUSDT_BINANCE.id,
            OrderSide.SELL,
            Quantity.from_str("0.50000000"),
        )

        fill = TestStubs.event_order_filled(
            order,
            instrument=BTCUSDT_BINANCE,
            position_id=PositionId("P-123456"),
            strategy_id=StrategyId("S-001"),
            last_px=Price.from_str("45500.00"),
        )

        position = Position(BTCUSDT_BINANCE, fill)

        # Act
        result = account.calculate_pnls(
            instrument=BTCUSDT_BINANCE,
            position=position,
            fill=fill,
        )

        # Assert
        assert result == [Money(-0.50000000, BTC), Money(22750.00000000, USDT)]

    def test_calculate_pnls_for_multi_currency_cash_account_adabtc(self):
        # Arrange
        event = AccountState(
            client_id=ClientId("SIM"),
            account_id=AccountId("SIM", "001"),
            account_type=AccountType.CASH,
            base_currency=None,  # Multi-currency
            reported=True,
            balances=[
                AccountBalance(
                    BTC,
                    Money(1.00000000, BTC),
                    Money(0.00000000, BTC),
                    Money(1.00000000, BTC),
                ),
                AccountBalance(
                    ADA,
                    Money(1000.00000000, ADA),
                    Money(0.00000000, ADA),
                    Money(1000.00000000, ADA),
                ),
            ],
            info={},  # No default currency set
            event_id=uuid4(),
            ts_event=0,
            ts_init=0,
        )

        account = CashAccount(event)

        order = self.order_factory.market(
            ADABTC_BINANCE.id,
            OrderSide.BUY,
            Quantity.from_int(100),
        )

        fill = TestStubs.event_order_filled(
            order,
            instrument=ADABTC_BINANCE,
            position_id=PositionId("P-123456"),
            strategy_id=StrategyId("S-001"),
            last_px=Price.from_str("0.00004100"),
        )

        position = Position(ADABTC_BINANCE, fill)

        # Act
        result = account.calculate_pnls(
            instrument=ADABTC_BINANCE,
            position=position,
            fill=fill,
        )

        # Assert
        assert result == [Money(100.000000, ADA), Money(-0.00410000, BTC)]

    def test_calculate_commission_when_given_liquidity_side_none_raises_value_error(
        self,
    ):
        # Arrange
        account = TestStubs.cash_account()
        instrument = TestInstrumentProvider.xbtusd_bitmex()

        # Act, Assert
        with pytest.raises(ValueError):
            account.calculate_commission(
                instrument=instrument,
                last_qty=Quantity.from_int(100000),
                last_px=Decimal("11450.50"),
                liquidity_side=LiquiditySide.NONE,
            )

    @pytest.mark.parametrize(
        "inverse_as_quote, expected",
        [
            [False, Money(-0.00218331, BTC)],  # Negative commission = credit
            [True, Money(-25.00, USD)],  # Negative commission = credit
        ],
    )
    def test_calculate_commission_for_inverse_maker_crypto(self, inverse_as_quote, expected):
        # Arrange
        account = TestStubs.cash_account()
        instrument = TestInstrumentProvider.xbtusd_bitmex()

        # Act
        result = account.calculate_commission(
            instrument=instrument,
            last_qty=Quantity.from_int(100000),
            last_px=Decimal("11450.50"),
            liquidity_side=LiquiditySide.MAKER,
            inverse_as_quote=inverse_as_quote,
        )

        # Assert
        assert result == expected

    def test_calculate_commission_for_taker_fx(self):
        # Arrange
        account = TestStubs.cash_account()
        instrument = AUDUSD_SIM

        # Act
        result = account.calculate_commission(
            instrument=instrument,
            last_qty=Quantity.from_int(1500000),
            last_px=Decimal("0.80050"),
            liquidity_side=LiquiditySide.TAKER,
        )

        # Assert
        assert result == Money(24.02, USD)

    def test_calculate_commission_crypto_taker(self):
        # Arrange
        account = TestStubs.cash_account()
        instrument = TestInstrumentProvider.xbtusd_bitmex()

        # Act
        result = account.calculate_commission(
            instrument=instrument,
            last_qty=Quantity.from_int(100000),
            last_px=Decimal("11450.50"),
            liquidity_side=LiquiditySide.TAKER,
        )

        # Assert
        assert result == Money(0.00654993, BTC)

    def test_calculate_commission_fx_taker(self):
        # Arrange
        account = TestStubs.cash_account()
        instrument = TestInstrumentProvider.default_fx_ccy("USD/JPY", Venue("IDEALPRO"))

        # Act
        result = account.calculate_commission(
            instrument=instrument,
            last_qty=Quantity.from_int(2200000),
            last_px=Decimal("120.310"),
            liquidity_side=LiquiditySide.TAKER,
        )

        # Assert
        assert result == Money(5294, JPY)


class TestMarginAccount:
    def setup(self):
        # Fixture Setup
        self.clock = TestClock()
        self.logger = Logger(self.clock)

        self.trader_id = TestStubs.trader_id()

        self.order_factory = OrderFactory(
            trader_id=self.trader_id,
            strategy_id=StrategyId("S-001"),
            clock=TestClock(),
        )

        self.msgbus = MessageBus(
            trader_id=self.trader_id,
            clock=self.clock,
            logger=self.logger,
        )

        self.cache = TestStubs.cache()

        self.portfolio = Portfolio(
            msgbus=self.msgbus,
            cache=self.cache,
            clock=self.clock,
            logger=self.logger,
        )

        self.exec_engine = ExecutionEngine(
            msgbus=self.msgbus,
            cache=self.cache,
            clock=self.clock,
            logger=self.logger,
        )

    def test_instantiated_accounts_basic_properties(self):
        # Arrange, Act
        account = TestStubs.margin_account()

        # Assert
        assert account.id == AccountId("SIM", "000")
        assert str(account) == "MarginAccount(id=SIM-000, type=MARGIN, base=USD)"
        assert repr(account) == "MarginAccount(id=SIM-000, type=MARGIN, base=USD)"
        assert isinstance(hash(account), int)
        assert account == account
        assert not account != account

    def test_set_leverage(self):
        # Arrange
        account = TestStubs.margin_account()

        # Act
        account.set_leverage(AUDUSD_SIM.id, Decimal(100))

        # Assert
        assert account.leverage(AUDUSD_SIM.id) == Decimal(100)
        assert account.leverages() == {AUDUSD_SIM.id: Decimal(100)}

    def test_update_initial_margin(self):
        # Arrange
        account = TestStubs.margin_account()
        margin = Money(0.00100000, BTC)

        # Act
        account.update_initial_margin(margin)

        # Assert
        assert account.initial_margin(BTC) == margin
        assert account.initial_margins() == {BTC: margin}

    def test_update_maint_margin(self):
        # Arrange
        account = TestStubs.margin_account()
        margin = Money(0.00050000, BTC)

        # Act
        account.update_maint_margin(margin)

        # Assert
        assert account.maint_margin(BTC) == margin
        assert account.maint_margins() == {BTC: margin}

    def test_calculate_initial_margin_with_leverage(self):
        # Arrange
        account = TestStubs.margin_account()
        instrument = TestInstrumentProvider.default_fx_ccy("AUD/USD")
        account.set_leverage(instrument.id, Decimal(50))

        result = account.calculate_initial_margin(
            instrument=instrument,
            quantity=Quantity.from_int(100000),
            price=Price.from_str("0.80000"),
        )

        # Assert
        assert result == Money(48.06, USD)

    @pytest.mark.parametrize(
        "inverse_as_quote, expected",
        [
            [False, Money(0.10005568, BTC)],
            [True, Money(1150.00, USD)],
        ],
    )
    def test_calculate_initial_margin_with_no_leverage_for_inverse(
        self, inverse_as_quote, expected
    ):
        # Arrange
        account = TestStubs.margin_account()
        instrument = TestInstrumentProvider.xbtusd_bitmex()

        result = account.calculate_initial_margin(
            instrument=instrument,
            quantity=Quantity.from_int(100000),
            price=Price.from_str("11493.60"),
            inverse_as_quote=inverse_as_quote,
        )

        # Assert
        assert result == expected

    def test_calculate_maint_margin_with_no_leverage(self):
        # Arrange
        account = TestStubs.margin_account()
        instrument = TestInstrumentProvider.xbtusd_bitmex()

        # Act
        result = account.calculate_maint_margin(
            instrument=instrument,
            side=PositionSide.LONG,
            quantity=Quantity.from_int(100000),
            last=Price.from_str("11493.60"),
        )

        # Assert
        assert result == Money(0.03697710, BTC)
