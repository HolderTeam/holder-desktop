from __future__ import annotations

from abc import ABC, abstractmethod


class FrontendDriver(ABC):
    """Minimal cross-client driver contract used by shared Behave steps."""

    @abstractmethod
    def launch(self) -> None:
        raise NotImplementedError

    @abstractmethod
    def shutdown(self) -> None:
        raise NotImplementedError

    @abstractmethod
    def create_card(self) -> None:
        raise NotImplementedError

    @abstractmethod
    def has_card_titled_prefix(self, prefix: str) -> bool:
        raise NotImplementedError
