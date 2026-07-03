<?php
class CheckoutService {
    public function createCheckout(array $payload): array { return $payload; }
    public function approveCheckout(int $id): bool { return true; }
}
