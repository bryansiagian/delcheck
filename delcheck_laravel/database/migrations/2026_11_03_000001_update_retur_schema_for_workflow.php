<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Evolve the existing Return tables without removing legacy columns/data.
     *
     * If a legacy Return already contains multiple item rows, stop before any
     * schema change. The new one-product-per-application rule cannot safely
     * choose which legacy item should remain.
     */
    public function up(): void
    {
        $hasDuplicateItems = DB::table('item_retur')
            ->select('retur_id')
            ->groupBy('retur_id')
            ->havingRaw('COUNT(*) > 1')
            ->exists();

        if ($hasDuplicateItems) {
            throw new RuntimeException(
                'Migration Return dibatalkan: ditemukan pengajuan dengan lebih dari satu item. '
                .'Tinjau dan putuskan penanganan data lama sebelum menerapkan batas satu produk per pengajuan.'
            );
        }

        $hasJenisPenyelesaian = Schema::hasColumn('retur', 'jenis_penyelesaian');
        $hasCatatanJemput = Schema::hasColumn('retur', 'catatan_jemput');

        Schema::table('retur', function (Blueprint $table) use ($hasJenisPenyelesaian, $hasCatatanJemput): void {
            if (! $hasJenisPenyelesaian) {
                // Nullable untuk menjaga record lama; pengajuan baru wajib diisi oleh validasi backend.
                $table->string('jenis_penyelesaian', 20)->nullable();
            }

            if (! $hasCatatanJemput) {
                $table->text('catatan_jemput')->nullable();
            }

            // Status tetap varchar; perubahan default tidak mengubah status record lama.
            $table->string('status', 30)->default('draft')->change();
        });

        $hasJenisFoto = Schema::hasColumn('foto_bukti', 'jenis');
        Schema::table('foto_bukti', function (Blueprint $table) use ($hasJenisFoto): void {
            if (! $hasJenisFoto) {
                // Contoh nilai: kondisi_produk, bukti_penjemputan. Bukan DB ENUM.
                $table->string('jenis', 30)->nullable();
            }
        });

        Schema::table('item_retur', function (Blueprint $table): void {
            $table->unique('retur_id', 'item_retur_one_product_unique');
        });
    }

    public function down(): void
    {
        $kolomBerisiData = [];

        foreach ([
            ['retur', 'jenis_penyelesaian'],
            ['retur', 'catatan_jemput'],
            ['foto_bukti', 'jenis'],
        ] as [$tabel, $kolom]) {
            if (
                Schema::hasColumn($tabel, $kolom)
                && DB::table($tabel)->whereNotNull($kolom)->exists()
            ) {
                $kolomBerisiData[] = "{$tabel}.{$kolom}";
            }
        }

        if ($kolomBerisiData !== []) {
            throw new RuntimeException(
                'Rollback migration Return ditolak karena berisiko kehilangan data pada kolom: '
                .implode(', ', $kolomBerisiData)
                .'. Tidak ada perubahan yang dilakukan. Amankan atau migrasikan data tersebut secara eksplisit sebelum rollback.'
            );
        }

        Schema::table('item_retur', function (Blueprint $table): void {
            $table->dropUnique('item_retur_one_product_unique');
        });

        $hasJenisFoto = Schema::hasColumn('foto_bukti', 'jenis');
        Schema::table('foto_bukti', function (Blueprint $table) use ($hasJenisFoto): void {
            if ($hasJenisFoto) {
                $table->dropColumn('jenis');
            }
        });

        $hasJenisPenyelesaian = Schema::hasColumn('retur', 'jenis_penyelesaian');
        $hasCatatanJemput = Schema::hasColumn('retur', 'catatan_jemput');
        Schema::table('retur', function (Blueprint $table) use ($hasJenisPenyelesaian, $hasCatatanJemput): void {
            if ($hasCatatanJemput) {
                $table->dropColumn('catatan_jemput');
            }

            if ($hasJenisPenyelesaian) {
                $table->dropColumn('jenis_penyelesaian');
            }

            $table->string('status', 30)->default('diajukan')->change();
        });
    }
};
