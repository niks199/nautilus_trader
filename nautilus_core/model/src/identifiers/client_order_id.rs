// -------------------------------------------------------------------------------------------------
//  Copyright (C) 2015-2022 Nautech Systems Pty Ltd. All rights reserved.
//  https://nautechsystems.io
//
//  Licensed under the GNU Lesser General Public License Version 3.0 (the "License");
//  You may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://www.gnu.org/licenses/lgpl-3.0.en.html
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
// -------------------------------------------------------------------------------------------------

use nautilus_core::string::{pystr_to_string, string_to_pystr};
use pyo3::ffi;
use std::collections::hash_map::DefaultHasher;
use std::fmt::{Debug, Display, Formatter, Result};
use std::hash::{Hash, Hasher};

#[repr(C)]
#[derive(Clone, Hash, PartialEq, Debug)]
#[allow(clippy::box_collection)] // C ABI compatibility
pub struct ClientOrderId {
    value: Box<String>,
}

impl From<&str> for ClientOrderId {
    fn from(s: &str) -> ClientOrderId {
        ClientOrderId {
            value: Box::new(s.to_string()),
        }
    }
}

impl Display for ClientOrderId {
    fn fmt(&self, f: &mut Formatter<'_>) -> Result {
        write!(f, "{}", self.value)
    }
}

////////////////////////////////////////////////////////////////////////////////
// C API
////////////////////////////////////////////////////////////////////////////////
#[no_mangle]
pub extern "C" fn client_order_id_free(client_order_id: ClientOrderId) {
    drop(client_order_id); // Memory freed here
}

/// Returns a Nautilus identifier from a valid Python object pointer.
///
/// # Safety
/// - `ptr` must be borrowed from a valid Python UTF-8 `str`.
#[no_mangle]
pub unsafe extern "C" fn client_order_id_from_pystr(ptr: *mut ffi::PyObject) -> ClientOrderId {
    ClientOrderId {
        value: Box::new(pystr_to_string(ptr)),
    }
}

/// Returns a pointer to a valid Python UTF-8 string.
///
/// # Safety
/// - Assumes that since the data is originating from Rust, the GIL does not need
/// to be acquired.
/// - Assumes you are immediately returning this pointer to Python.
#[no_mangle]
pub unsafe extern "C" fn client_order_id_to_pystr(
    client_order_id: &ClientOrderId,
) -> *mut ffi::PyObject {
    string_to_pystr(client_order_id.value.as_str())
}

#[no_mangle]
pub extern "C" fn client_order_id_eq(lhs: &ClientOrderId, rhs: &ClientOrderId) -> u8 {
    (lhs == rhs) as u8
}

#[no_mangle]
pub extern "C" fn client_order_id_hash(client_order_id: &ClientOrderId) -> u64 {
    let mut h = DefaultHasher::new();
    client_order_id.hash(&mut h);
    h.finish()
}

////////////////////////////////////////////////////////////////////////////////
// Tests
////////////////////////////////////////////////////////////////////////////////
#[cfg(test)]
mod tests {
    use super::ClientOrderId;
    use crate::identifiers::client_order_id::client_order_id_free;

    #[test]
    fn test_equality() {
        let id1 = ClientOrderId::from("O-20200814-102234-001-001-1");
        let id2 = ClientOrderId::from("O-20200814-102234-001-001-2");

        assert_eq!(id1, id1);
        assert_ne!(id1, id2);
    }

    #[test]
    fn test_string_reprs() {
        let id = ClientOrderId::from("O-20200814-102234-001-001-1");

        assert_eq!(id.to_string(), "O-20200814-102234-001-001-1");
        assert_eq!(format!("{id}"), "O-20200814-102234-001-001-1");
    }

    #[test]
    fn test_client_order_id_free() {
        let id = ClientOrderId::from("O-20200814-102234-001-001-1");

        client_order_id_free(id); // No panic
    }
}