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


cdef class FillModel:
    cdef readonly double prob_fill_on_limit
    """The probability of limit orders filling on the limit price.\n\n:returns: `bool`"""
    cdef readonly double prob_fill_on_stop
    """The probability of stop orders filling on the stop price.\n\n:returns: `bool`"""
    cdef readonly double prob_slippage
    """The probability of aggressive order execution slipping.\n\n:returns: `bool`"""

    cpdef bint is_limit_filled(self) except *
    cpdef bint is_stop_filled(self) except *
    cpdef bint is_slipped(self) except *

    cdef bint _event_success(self, double probability) except *