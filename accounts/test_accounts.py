# Copyright (c) 2023 Cisco Systems, Inc. and its affiliates All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

"""Unit tests for the accounts microservice.

These tests exercise the ``AccountsGeneric`` business logic and the Flask
HTTP routes without requiring a live MongoDB instance: the module-level
``collection`` is replaced with a ``MagicMock`` so every database call is
stubbed and assertions can be made against how it is used.
"""

import os

# accounts.py reads these at import time (and raises if DB_URL is missing),
# so they must be set before the module is imported. The value is never used
# because the Mongo collection is mocked in every test.
os.environ.setdefault("DB_URL", "mongodb://localhost:27017")
os.environ.setdefault("SERVICE_PROTOCOL", "http")

from unittest.mock import MagicMock

import pytest
from dotmap import DotMap

import accounts


@pytest.fixture
def mock_collection(monkeypatch):
    """Replace the module-level Mongo collection with a mock."""
    mock = MagicMock()
    monkeypatch.setattr(accounts, "collection", mock)
    return mock


@pytest.fixture
def client():
    """Flask test client for exercising the HTTP routes."""
    accounts.app.config["TESTING"] = True
    with accounts.app.test_client() as test_client:
        yield test_client


def _sample_create_request():
    """A DotMap mirroring the payload the create-account route builds."""
    return DotMap(
        {
            "email_id": "ada@example.com",
            "account_type": "Savings",
            "address": "1 Analytical Engine Way",
            "govt_id_number": "X1",
            "government_id_type": "passport",
            "name": "Ada Lovelace",
        }
    )


class TestGetAccountDetails:
    def test_returns_only_public_fields_when_found(self, mock_collection):
        mock_collection.find_one.return_value = {
            "account_number": "IBAN1234567890123456",
            "name": "Ada Lovelace",
            "balance": 250,
            "currency": "USD",
            # fields that must NOT be leaked back to the caller:
            "email_id": "ada@example.com",
            "govt_id_number": "X1",
        }

        result = accounts.AccountsGeneric().getAccountDetails(
            DotMap({"account_number": "IBAN1234567890123456"})
        )

        assert result == {
            "account_number": "IBAN1234567890123456",
            "name": "Ada Lovelace",
            "balance": 250,
            "currency": "USD",
        }
        mock_collection.find_one.assert_called_once_with(
            {"account_number": "IBAN1234567890123456"}
        )

    def test_returns_empty_dict_when_not_found(self, mock_collection):
        mock_collection.find_one.return_value = None

        result = accounts.AccountsGeneric().getAccountDetails(
            DotMap({"account_number": "does-not-exist"})
        )

        assert result == {}


class TestCreateAccount:
    def test_creates_account_when_not_duplicate(self, mock_collection):
        mock_collection.count_documents.return_value = 0

        result = accounts.AccountsGeneric().createAccount(_sample_create_request())

        assert result is True
        mock_collection.insert_one.assert_called_once()

        inserted = mock_collection.insert_one.call_args.args[0]
        # new accounts get sensible server-assigned defaults
        assert inserted["balance"] == 100
        assert inserted["currency"] == "USD"
        assert inserted["account_number"].startswith("IBAN")
        assert "created_at" in inserted
        # client-supplied fields are persisted as-is
        assert inserted["email_id"] == "ada@example.com"
        assert inserted["name"] == "Ada Lovelace"

    def test_rejects_duplicate_account(self, mock_collection):
        mock_collection.count_documents.return_value = 1

        result = accounts.AccountsGeneric().createAccount(_sample_create_request())

        assert result is False
        mock_collection.insert_one.assert_not_called()

    def test_duplicate_check_uses_email_and_account_type(self, mock_collection):
        mock_collection.count_documents.return_value = 0

        accounts.AccountsGeneric().createAccount(_sample_create_request())

        mock_collection.count_documents.assert_called_once_with(
            {"email_id": "ada@example.com", "account_type": "Savings"}
        )


class TestGetAccounts:
    def test_filters_to_allowed_fields(self, mock_collection):
        mock_collection.find.return_value = [
            {
                "_id": "mongo-object-id",
                "account_number": "IBAN1",
                "email_id": "ada@example.com",
                "account_type": "Savings",
                "address": "1 Analytical Engine Way",
                "govt_id_number": "X1",
                "government_id_type": "passport",
                "name": "Ada Lovelace",
                "balance": 100,
                "currency": "USD",
                "created_at": "2023-01-01",
            }
        ]

        result = accounts.AccountsGeneric().getAccounts(
            DotMap({"email_id": "ada@example.com"})
        )

        assert len(result) == 1
        # internal/sensitive bookkeeping fields are stripped
        assert "_id" not in result[0]
        assert "created_at" not in result[0]
        assert result[0]["account_number"] == "IBAN1"
        mock_collection.find.assert_called_once_with({"email_id": "ada@example.com"})

    def test_returns_empty_list_when_no_accounts(self, mock_collection):
        mock_collection.find.return_value = []

        result = accounts.AccountsGeneric().getAccounts(
            DotMap({"email_id": "nobody@example.com"})
        )

        assert result == []


class TestFlaskRoutes:
    def test_account_detail_route(self, client, mock_collection):
        mock_collection.find_one.return_value = {
            "account_number": "IBAN1",
            "name": "Ada Lovelace",
            "balance": 100,
            "currency": "USD",
        }

        response = client.post("/account-detail", json={"account_number": "IBAN1"})

        assert response.status_code == 200
        assert response.get_json() == {
            "account_number": "IBAN1",
            "name": "Ada Lovelace",
            "balance": 100,
            "currency": "USD",
        }

    def test_create_account_route(self, client, mock_collection):
        mock_collection.count_documents.return_value = 0

        response = client.post(
            "/create-account",
            json={
                "email_id": "ada@example.com",
                "account_type": "Savings",
                "address": "1 Analytical Engine Way",
                "govt_id_number": "X1",
                "government_id_type": "passport",
                "name": "Ada Lovelace",
            },
        )

        assert response.status_code == 200
        assert response.get_json() is True
        mock_collection.insert_one.assert_called_once()

    def test_get_all_accounts_route(self, client, mock_collection):
        mock_collection.find.return_value = [
            {
                "_id": "mongo-object-id",
                "account_number": "IBAN1",
                "email_id": "ada@example.com",
                "account_type": "Savings",
                "address": "1 Analytical Engine Way",
                "govt_id_number": "X1",
                "government_id_type": "passport",
                "name": "Ada Lovelace",
                "balance": 100,
                "currency": "USD",
            }
        ]

        response = client.post(
            "/get-all-accounts", json={"email_id": "ada@example.com"}
        )

        assert response.status_code == 200
        data = response.get_json()
        assert len(data) == 1
        assert "_id" not in data[0]
        assert data[0]["account_number"] == "IBAN1"
