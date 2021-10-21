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

import asyncio
import types
from typing import Callable, Optional

from nautilus_trader.common.logging cimport Logger
from nautilus_trader.common.logging cimport LoggerAdapter
from nautilus_trader.core.correctness cimport Condition


cdef class SocketClient:
    """
    Provides a low-level generic socket base client.
    """

    def __init__(
        self,
        loop not None: asyncio.AbstractEventLoop,
        Logger logger not None: Logger,
        host,
        port,
        handler not None: Callable,
        bint ssl=True,
        bytes crlf=None,
        str encoding="utf-8",
    ):
        """
        Initialize a new instance of the ``WebSocketClient`` class.

        Parameters
        ----------
        loop : asyncio.AbstractEventLoop
            The event loop for the client.
        logger : Logger
            The logger for the client.
        host : str
            The host for the client.
        port : int
            The port for the client.
        handler : Callable
            The handler to process the raw bytes read.
        ssl : bool
            If SSL should be used for socket connection.
        crlf : bytes, optional
            The carriage return, line feed delimiter on which to split messages.
        encoding : str, optional
            The encoding to use when sending messages.

        Raises
        ------
        ValueError
            If host is not a valid string.
        ValueError
            If port is not positive (> 0).

        """
        Condition.valid_string(host, "host")
        Condition.positive_int(port, "port")

        self.host = host
        self.port = port
        self.ssl = ssl
        self._loop = loop
        self._log = LoggerAdapter(
            component_name=type(self).__name__,
            logger=logger,
        )
        self._reader: Optional[asyncio.StreamReader] = None
        self._writer: Optional[asyncio.StreamWriter] = None
        self._handler = handler

        self._crlf = crlf or b"\r\n"
        self._encoding = encoding
        self._running = False
        self._stopped = False
        self.is_connected = False

    async def connect(self):
        if not self.is_connected:
            self._reader, self._writer = await asyncio.open_connection(
                host=self.host,
                port=self.port,
                loop=self._loop,
                ssl=self.ssl,
            )
            await self.post_connection()
            self._loop.create_task(self.start())
            self._running = True
            self.is_connected = True

    async def disconnect(self):
        self.stop()
        while not self._stopped:
            await asyncio.sleep(0.01)
        self._writer.close()
        await self._writer.wait_closed()
        self._reader = None
        self._writer = None
        self.is_connected = False

    def stop(self):
        self._running = False

    async def reconnect(self):
        await self.disconnect()
        await self.connect()

    async def post_connection(self):
        """
        The actions to perform post-connection. i.e. sending further connection messages.
        """
        await self._sleep0()

    async def send(self, bytes raw):
        self._log.debug("[SEND] " + raw.decode())
        self._writer.write(raw + self._crlf)
        await self._writer.drain()

    async def start(self):
        self._log.debug("Starting recv loop")

        cdef:
            bytes partial = b""
            bytes raw = b""
        while self._running:
            try:
                raw = await self._reader.readuntil(separator=self._crlf)
                if partial:
                    raw += partial
                    partial = b""
                self._log.debug("[RECV] " + raw.decode())
                self._handler(raw.rstrip(self._crlf))
                await self._sleep0()
            except asyncio.IncompleteReadError as ex:
                partial = ex.partial
                self._log.warning(str(ex))
                await self._sleep0()
                continue
            except ConnectionResetError:
                await self.connect()
        self._stopped = True

    @types.coroutine
    def _sleep0(self):
        # Skip one event loop run cycle.
        #
        # This is equivalent to `asyncio.sleep(0)` however avoids the overhead
        # of the pure Python function call and integer comparison <= 0.
        #
        # Uses a bare 'yield' expression (which Task.__step knows how to handle)
        # instead of creating a Future object.
        yield