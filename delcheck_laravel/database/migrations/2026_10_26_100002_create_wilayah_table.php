<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wilayah', function (Blueprint $table) {
            $table->id();
            $table->foreignId('parent_id')->nullable()->constrained('wilayah')->nullOnDelete();
            $table->string('kode', 20)->unique();
            $table->string('nama');
            $table->string('tingkat', 20)->default('kota'); // provinsi, kota, kecamatan
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wilayah');
    }
};
