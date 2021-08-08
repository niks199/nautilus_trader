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

from nautilus_trader.model.c_enums.account_type cimport AccountType
from nautilus_trader.model.c_enums.liquidity_side cimport LiquiditySide
from nautilus_trader.model.c_enums.position_side cimport PositionSide
from nautilus_trader.model.currency cimport Currency
from nautilus_trader.model.events.account cimport AccountState
from nautilus_trader.model.events.order cimport OrderFilled
from nautilus_trader.model.identifiers cimport AccountId
from nautilus_trader.model.identifiers cimport InstrumentId
from nautilus_trader.model.instruments.base cimport Instrument
from nautilus_trader.model.objects cimport AccountBalance
from nautilus_trader.model.objects cimport Money
from nautilus_trader.model.objects cimport Price
from nautilus_trader.model.objects cimport Quantity
from nautilus_trader.model.position cimport Position


cdef class Account:
    cdef list _events
    cdef dict _starting_balances
    cdef dict _balances
    cdef dict _commissions

    cdef readonly AccountId id
    """The accounts ID.\n\n:returns: `AccountId`"""
    cdef readonly AccountType type
    """The accounts type.\n\n:returns: `AccountType`"""
    cdef readonly Currency base_currency
    """The accounts base currency (None for multi-currency accounts).\n\n:returns: `Currency` or None"""

    @staticmethod
    cdef Account create_c(AccountState event)

# -- INTERNAL --------------------------------------------------------------------------------------

    cdef inline void _update_balances(self, list account_balances) except *

# -- QUERIES ---------------------------------------------------------------------------------------

    cdef AccountState last_event_c(self)
    cdef list events_c(self)
    cdef int event_count_c(self)

    cpdef list currencies(self)
    cpdef dict starting_balances(self)
    cpdef dict balances(self)
    cpdef dict balances_total(self)
    cpdef dict balances_free(self)
    cpdef dict balances_locked(self)
    cpdef dict commissions(self)
    cpdef AccountBalance balance(self, Currency currency=*)
    cpdef Money balance_total(self, Currency currency=*)
    cpdef Money balance_free(self, Currency currency=*)
    cpdef Money balance_locked(self, Currency currency=*)
    cpdef Money commission(self, Currency currency)

# -- COMMANDS --------------------------------------------------------------------------------------

    cpdef void apply(self, AccountState event) except *
    cpdef void update_commissions(self, Money commission) except *

# -- CALCULATIONS ----------------------------------------------------------------------------------

    cpdef Money calculate_commission(
        self,
        Instrument instrument,
        Quantity last_qty,
        last_px: Decimal,
        LiquiditySide liquidity_side,
        bint inverse_as_quote=*,
    )
    cpdef list calculate_pnls(self, Instrument instrument, Position position, OrderFilled fill)


cdef class CashAccount(Account):
    pass


cdef class MarginAccount(Account):
    cdef dict _leverages
    cdef dict _initial_margins
    cdef dict _maint_margins

# -- QUERIES ---------------------------------------------------------------------------------------

    cpdef dict leverages(self)
    cpdef dict initial_margins(self)
    cpdef dict maint_margins(self)
    cpdef object leverage(self, InstrumentId instrument_id)
    cpdef Money initial_margin(self, Currency currency=*)
    cpdef Money maint_margin(self, Currency currency=*)

# -- COMMANDS --------------------------------------------------------------------------------------

    cpdef void set_leverage(self, InstrumentId instrument_id, leverage: Decimal) except *
    cpdef void update_initial_margin(self, Money margin) except *
    cpdef void update_maint_margin(self, Money margin) except *

# -- CALCULATIONS ----------------------------------------------------------------------------------

    cpdef Money calculate_initial_margin(
        self,
        Instrument instrument,
        Quantity quantity,
        Price price,
        bint inverse_as_quote=*,
    )
    cpdef Money calculate_maint_margin(
        self,
        Instrument instrument,
        PositionSide side,
        Quantity quantity,
        Price last,
        bint inverse_as_quote=*,
    )
