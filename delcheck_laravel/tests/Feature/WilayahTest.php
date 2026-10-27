<?php

namespace Tests\Feature;

use App\Models\Wilayah;
use Database\Seeders\WilayahSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class WilayahTest extends TestCase
{
    use RefreshDatabase;

    public function test_wilayah_dapat_diakses_tanpa_login(): void
    {
        $this->seed(WilayahSeeder::class);

        $this->getJson('/api/wilayah')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['data' => [['id', 'kode', 'nama', 'tingkat', 'parent_id']]]);
    }

    public function test_filter_tingkat_provinsi(): void
    {
        $this->seed(WilayahSeeder::class);

        $data = $this->getJson('/api/wilayah?tingkat=provinsi')->assertOk()->json('data');

        $this->assertNotEmpty($data);
        $this->assertSame(['provinsi'], collect($data)->pluck('tingkat')->unique()->values()->all());
    }

    public function test_filter_berdasarkan_induk(): void
    {
        $this->seed(WilayahSeeder::class);
        $sumut = Wilayah::where('kode', '12')->value('id');

        $nama = collect($this->getJson("/api/wilayah?parent_id={$sumut}")->assertOk()->json('data'))->pluck('nama');

        $this->assertTrue($nama->contains('Kota Medan'));
        $this->assertFalse($nama->contains('Kota Jakarta Pusat'));
    }
}
