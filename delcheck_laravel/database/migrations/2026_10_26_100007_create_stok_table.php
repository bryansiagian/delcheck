<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stok_produk', function (Blueprint $table) {
            $table->id();
            $table->foreignId('produk_id')->unique()->constrained('produk')->cascadeOnDelete();
            $table->unsignedInteger('jumlah')->default(0);   // tidak boleh negatif (BR / UC-A03)
            $table->timestamps();
        });

        Schema::create('mutasi_stok', function (Blueprint $table) {
            $table->id();
            $table->foreignId('produk_id')->constrained('produk');
            $table->string('tipe', 20);                      // masuk, keluar, penyesuaian, retur
            $table->integer('jumlah');                       // bertanda: + masuk, - keluar
            $table->unsignedInteger('stok_sebelum');
            $table->unsignedInteger('stok_sesudah');
            $table->string('alasan')->nullable();
            $table->nullableMorphs('referensi');             // mis. Pesanan saat status Dikirim (BR-07)
            $table->foreignId('dibuat_oleh')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['produk_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('mutasi_stok');
        Schema::dropIfExists('stok_produk');
    }
};
