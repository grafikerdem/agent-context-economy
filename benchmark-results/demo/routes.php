<?php
Route::post('/checkout', 'CheckoutController@store');
Route::post('/checkout/{checkout}/approve', 'CheckoutController@approve');
